"""korinf/downgrade-stray-packages: a version no repository has is replaced with the repository one."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'share/eterbuild/korinf/downgrade-stray-packages'


class DowngradeStrayPackages(unittest.TestCase):
    def run_script(self, status, madison):
        with tempfile.TemporaryDirectory() as tmp:
            bindir = Path(tmp)
            calls = bindir / 'calls'
            (bindir / 'madison').write_text(madison)
            stubs = {
                'dpkg-query': f'#!/bin/sh\n[ -n "{status}" ] || exit 1\nprintf "%s" "{status}"\n',
                'apt-cache': f'#!/bin/sh\ncat {bindir}/madison\n',
                'apt-get': f'#!/bin/sh\necho "apt-get $*" >> {calls}\n',
            }
            for name, text in stubs.items():
                (bindir / name).write_text(text)
                (bindir / name).chmod(0o755)
            r = subprocess.run(['sh', str(SCRIPT), 'libpq5'], capture_output=True, text=True,
                               env=dict(os.environ, PATH=f'{bindir}:{os.environ["PATH"]}'))
            return r, calls.read_text() if calls.exists() else ''

    MADISON = ('    libpq5 | 15.18-astra.se5.1 | https://download.astralinux.ru main amd64 Packages\n'
               '    libpq5 | 15.10-astra.se1 | https://download.astralinux.ru main amd64 Packages\n')

    def test_stray_version_replaced(self):
        r, calls = self.run_script('install ok installed 1:11.21-astra.se8', self.MADISON)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('--allow-downgrades', calls)
        self.assertIn('install libpq5=15.18-astra.se5.1', calls)

    def test_repository_version_untouched(self):
        for status in ('install ok installed 15.10-astra.se1', '', 'deinstall ok config-files 1:11.21'):
            with self.subTest(status=status):
                r, calls = self.run_script(status, self.MADISON)
                self.assertEqual(r.returncode, 0, r.stderr)
                self.assertEqual(calls, '')

    def test_not_in_repositories_untouched(self):
        r, calls = self.run_script('install ok installed 1:11.21-astra.se8', '')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(calls, '')


if __name__ == '__main__':
    unittest.main()
