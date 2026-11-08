"""korinf/remove-broken-eepm-full: an unconfigured eepm-full with uninstallable Depends is removed."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'share/eterbuild/korinf/remove-broken-eepm-full'


class RemoveBrokenEepmFull(unittest.TestCase):
    def run_script(self, status, fix_ok):
        with tempfile.TemporaryDirectory() as tmp:
            bindir = Path(tmp)
            calls = bindir / 'calls'
            stubs = {
                'dpkg-query': f'#!/bin/sh\nprintf "%s" "{status}"\n',
                'apt-get': f'#!/bin/sh\necho "apt-get $*" >> {calls}\nexit {0 if fix_ok else 100}\n',
                'dpkg': f'#!/bin/sh\necho "dpkg $*" >> {calls}\n',
            }
            for name, text in stubs.items():
                (bindir / name).write_text(text)
                (bindir / name).chmod(0o755)
            r = subprocess.run(['sh', str(SCRIPT)], capture_output=True, text=True,
                               env=dict(os.environ, PATH=f'{bindir}:{os.environ["PATH"]}'))
            return r, calls.read_text() if calls.exists() else ''

    def test_configured_or_absent_untouched(self):
        for status in ('install ok installed', '', 'deinstall ok config-files'):
            with self.subTest(status=status):
                r, calls = self.run_script(status, fix_ok=False)
                self.assertEqual(r.returncode, 0, r.stderr)
                self.assertEqual(calls, '')

    def test_fixed_when_depends_installable(self):
        r, calls = self.run_script('install ok unpacked', fix_ok=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('--fix-broken install', calls)
        self.assertNotIn('dpkg --remove', calls)

    def test_removed_when_depends_missing(self):
        r, calls = self.run_script('install ok unpacked', fix_ok=False)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('dpkg --remove eepm-full', calls)


if __name__ == '__main__':
    unittest.main()
