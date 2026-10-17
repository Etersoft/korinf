from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
COMPONENTS = ('nx-libs', 'prunner', 'nxssh', 'rx-etersoft', 'rxclient',
              'rx-etersoft-pcsc', 'rx-etersoft-pcsc-driver', 'kdriveclient', 'rx-etersoft-kdrive')

class RxBootstrap(unittest.TestCase):
    def run_build(self, fail='', nostop=False):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'functions').write_text('set_ver() { ver="$2"; }\n')
            for name in COMPONENTS:
                p = root / (name + '.sh')
                p.write_text('#!/bin/sh\necho '+name+' >> calls\nexit '+('7' if name == fail else '0')+'\n')
                p.chmod(0o755)
            args = ['sh', str(ROOT / 'bin-rx/build-rx-bootstrap-new.sh'), '--force']
            if nostop: args.append('--nostop')
            result = subprocess.run(args+['x86_64/ALTLinux/Sisyphus', '1.10'], cwd=root,
                                    capture_output=True, text=True)
            return result.returncode, (root / 'calls').read_text().splitlines()

    def test_success_returns_zero(self):
        rc, calls = self.run_build()
        self.assertEqual(rc, 0)
        self.assertIn('rx-etersoft-kdrive', calls)

    def test_failure_stops_and_preserves_exit_code(self):
        rc, calls = self.run_build(fail='nx-libs')
        self.assertEqual(rc, 7)
        self.assertEqual(calls, ['nx-libs'])

    def test_nostop_continues_but_retains_failure(self):
        rc, calls = self.run_build(fail='nx-libs', nostop=True)
        self.assertEqual(rc, 7)
        self.assertIn('rx-etersoft-kdrive', calls)

if __name__ == '__main__':
    unittest.main()
