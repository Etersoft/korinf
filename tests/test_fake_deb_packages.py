"""Verify bootstrap placeholder migration without installing host packages."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'share/eterbuild/korinf/install-fake-deb-packages'


class FakeDebPackages(unittest.TestCase):
    def run_case(self, state, package='wine-etersoft-gecko'):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            query = root / 'dpkg-query'
            query.write_text('''#!/bin/sh
[ "$STATE" = missing ] && exit 1
case "$*" in
 *Status*) printf 'install ok installed';;
 *) printf '%s' "$STATE";;
esac
''')
            install = root / 'dpkg'
            install.write_text('''#!/bin/sh
[ "$1" = --install ] || exit 99
dpkg-deb --field "$2" Package Version Architecture Multi-Arch > "$RESULT"
''')
            query.chmod(0o755)
            install.chmod(0o755)
            out = root / 'result'
            env = dict(os.environ, PATH=str(root) + ':' + os.environ['PATH'],
                       STATE=state, RESULT=str(out))
            result = subprocess.run(['sh', str(SCRIPT), package], env=env,
                                    capture_output=True, text=True)
            return result, out.read_text() if out.exists() else ''

    def test_new_and_old_placeholders_support_foreign_architecture(self):
        for state in ('missing', '0|Korinf <builder@etersoft.ru>|'):
            with self.subTest(state=state):
                result, installed = self.run_case(state)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('Architecture: all', installed)
                self.assertIn('Multi-Arch: foreign', installed)
                self.assertIn('Version: 0', installed)

    def test_real_and_current_packages_are_not_replaced(self):
        for state in ('2.47.4|upstream|', '0|someone else|',
                      '0|Korinf <builder@etersoft.ru>|foreign'):
            with self.subTest(state=state):
                result, installed = self.run_case(state)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(installed, '')

    def test_invalid_package_is_rejected(self):
        result, installed = self.run_case('missing', '../bad')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(installed, '')


if __name__ == '__main__':
    unittest.main()
