"""A published package must not suppress installation into another image."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class CurrentPackageInstall(unittest.TestCase):
    def test_install_runs_even_when_published_binary_is_current(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / 'source.rpm'
            binary = Path(tmp) / 'binary.rpm'
            source.touch()
            binary.touch()
            os.utime(source, (1, 1))
            os.utime(binary, (2, 2))
            for install, expected in (('', 1), ('1', 0)):
                with self.subTest(install=install):
                    result = subprocess.run(['bash', '-c', '''
. "$CHECK_MODULE"
assert_var() { :; }
get_bin_package() { echo "$BINARY"; }
do_need_build_package example
'''], env=dict(os.environ, CHECK_MODULE=str(ROOT / 'share/eterbuild/korinf/check_built'),
    BINARY=str(binary), BUILDSRPM=str(source), DESTDIR=tmp, INSTALLREQUIREDPACKAGE=install),
                        capture_output=True, text=True)
                    self.assertEqual(result.returncode, expected, result.stderr)

if __name__ == '__main__':
    unittest.main()
