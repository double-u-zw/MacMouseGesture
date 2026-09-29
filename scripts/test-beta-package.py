#!/usr/bin/env python3
"""Mutation tests against the real signed bundle, not a synthetic schema copy."""
import pathlib, plistlib, shutil, subprocess, sys, tempfile
source = pathlib.Path(sys.argv[1])
verifier = pathlib.Path(__file__).with_name('verify-beta.py')
with tempfile.TemporaryDirectory() as temp:
    target = pathlib.Path(temp) / 'MacMouseGesture.app'
    for mutation in ['version', 'commit', 'dirty', 'notices', 'icon', 'binary']:
        if target.exists(): shutil.rmtree(target)
        shutil.copytree(source, target)
        plist = target / 'Contents/Info.plist'
        if mutation in ['version', 'commit', 'dirty']:
            p = plistlib.loads(plist.read_bytes())
            if mutation == 'version': p['CFBundleVersion'] = '12'
            if mutation == 'commit': p.pop('GitCommit')
            if mutation == 'dirty': p['SourceTreeDirty'] = True
            plist.write_bytes(plistlib.dumps(p))
        elif mutation == 'notices':
            (target / 'Contents/Resources/THIRD_PARTY_NOTICES.md').unlink()
        elif mutation == 'icon':
            (target / 'Contents/Resources/MacMouseGesture.icns').unlink()
        else:
            with (target / 'Contents/MacOS/MacMouseGesture').open('ab') as f: f.write(b'corruption')
        result = subprocess.run([sys.executable, str(verifier), str(target)], capture_output=True)
        assert result.returncode != 0, f'accepted broken {mutation}'
        print(f'PASS reject package mutation: {mutation}')
