#!/usr/bin/env python3
"""Read-only audit. Reports locations/categories, never matched secret values.
Includes all reachable Git objects, commit identities, tracked + unignored files.
Pattern scanning is not proof that all possible secrets have been found.
"""
import json, pathlib, re, subprocess
root = pathlib.Path(__file__).resolve().parent.parent

def git(*args):
    return subprocess.check_output(['git', '-C', str(root), *args])

patterns = {
    'private-key': re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----'),
    'github-token': re.compile(rb'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})'),
    'aws-key': re.compile(rb'AKIA[A-Z0-9]{16}'),
    'credential-assignment': re.compile(rb'(?i)(?:password|token|secret)\s*[:=]\s*[\x22\x27][A-Za-z0-9+/=_-]{16,}[\x22\x27]'),
}
private_path = ('/Users/' + pathlib.Path.home().name).encode()
identity_file = root / '.local-signing/identity.sha1'
identity = identity_file.read_bytes().strip().lower() if identity_file.exists() else b''
findings = []
seen = set()

def inspect(data, location, path=''):
    for kind, pattern in patterns.items():
        if pattern.search(data): findings.append(dict(category=kind, location=location))
    if private_path in data: findings.append(dict(category='personal-home', location=location))
    if identity and identity in data.lower(): findings.append(dict(category='local-public-certificate-fingerprint', location=location))
    if re.search(r'(^|/)(\.local-signing|references)/|\.(p12|pfx|keychain|keychain-db|pem)$', path):
        findings.append(dict(category='restricted-file', location=location))
    if len(data) > 1024 * 1024 and not path.endswith(('.png', '.icns')):
        findings.append(dict(category='large-non-icon-blob', location=location))

objects = git('rev-list', '--objects', '--all').decode().splitlines()
for line in objects:
    oid, _, path = line.partition(' ')
    if oid in seen: continue
    seen.add(oid)
    typ = git('cat-file', '-t', oid).strip()
    if typ == b'blob': inspect(git('cat-file', 'blob', oid), 'history:' + oid[:12] + ':' + path, path)
    elif typ == b'commit':
        data = git('cat-file', 'commit', oid)
        for role in [b'author', b'committer']:
            match = re.search(rb'^' + role + rb' .*?<([^>]+)>', data, re.M)
            if match and not match[1].endswith(b'@users.noreply.github.com'):
                findings.append(dict(category='commit-email-review', location='commit:' + oid[:12] + ':' + role.decode()))
for raw in git('ls-files', '-z', '--cached', '--others', '--exclude-standard').split(b'\0'):
    if not raw: continue
    path = raw.decode(); file = root / path
    if file.is_file(): inspect(file.read_bytes(), 'working:' + path, path)
print(json.dumps(dict(reachableObjects=len(seen), findings=findings,
    limitations='Pattern scan only; commit emails need owner decision; source licensing requires manual review.'), indent=2))
# Findings require review; this scanner does not publish anything.
raise SystemExit(1 if findings else 0)
