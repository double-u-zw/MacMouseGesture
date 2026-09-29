#!/usr/bin/env python3
"""Fail closed on metadata, contents, architectures and non-system load paths."""
import pathlib, plistlib, re, subprocess, sys

def verify(bundle):
    bundle = pathlib.Path(bundle)
    with (bundle / 'Contents/Info.plist').open('rb') as f:
        p = plistlib.load(f)
    expected = dict(CFBundleIdentifier='local.macmousegesture.poc', CFBundleExecutable='MacMouseGesture',
                    CFBundleName='MacMouseGesture', CFBundleIconFile='MacMouseGesture', CFBundleShortVersionString='0.2.0', CFBundleVersion='13',
                    BetaVersion='0.2.0-beta.1', CFBundlePackageType='APPL', LSMinimumSystemVersion='27.0', LSUIElement=True)
    for key, value in expected.items():
        assert p.get(key) == value, f'invalid {key}'
    assert re.fullmatch(r'[0-9a-f]{40}', p.get('GitCommit', '')), 'missing commit'
    assert p.get('SourceTreeDirty') is False, 'uncommitted source is not a release archive'
    exe = bundle / 'Contents/MacOS/MacMouseGesture'
    icon = bundle / 'Contents/Resources/MacMouseGesture.icns'
    assert icon.is_file() and icon.read_bytes()[:4] == b'icns', 'missing or invalid icon'
    assert exe.is_file() and exe.stat().st_mode & 0o111, 'missing executable'
    assert (bundle / 'Contents/Resources/THIRD_PARTY_NOTICES.md').is_file(), 'missing notices'
    assert subprocess.check_output(['lipo', '-archs', str(exe)], text=True).strip() == 'arm64'
    linked = subprocess.check_output(['otool', '-L', str(exe)], text=True)
    for line in linked.splitlines()[1:]:
        path = line.strip().split(' (')[0]
        assert path.startswith(('/System/Library/', '/usr/lib/')), f'unapproved dependency: {path}'
    loads = subprocess.check_output(['otool', '-l', str(exe)], text=True)
    assert 'LC_RPATH' not in loads, 'unexpected runtime search path'
    assert '/Users/' not in plistlib.dumps(p).decode(), 'private plist path'
    assert not list(bundle.rglob('*.dSYM')), 'symbols in user artifact'
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(bundle)], check=True)
    signature = subprocess.check_output(['codesign', '-d', '--verbose=4', str(bundle)], stderr=subprocess.STDOUT, text=True)
    assert 'runtime' in signature, 'hardened runtime missing'
    entitlements = subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(bundle)], stderr=subprocess.DEVNULL)
    assert not entitlements.strip() or not plistlib.loads(entitlements), 'unexpected entitlements'

if __name__ == '__main__':
    verify(sys.argv[1])
    print('PASS bundle metadata, architecture, dependencies, resources, HR, signature')
