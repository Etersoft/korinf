"""Check cpio's symlink behavior, including distro backports, before alien."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PROBE = ROOT / 'share/eterbuild/korinf/check-cpio'

class CpioCompatibility(unittest.TestCase):
    def run_shell(self, source, body):
        setup = f'KORINFDIR={ROOT}/share/eterbuild\nload_mod() {{ :; }}; kormod() {{ :; }}\n'
        return subprocess.run(['bash'], input=setup+source+'\n'+body,
                              text=True, capture_output=True)

    def test_conversion_stops_before_preparing_packages(self):
        source = (ROOT/'share/eterbuild/korinf/converts/deb').read_text()
        result = self.run_shell(source, '''
assert_var() { :; }
warning() { echo "$*"; }
run_in_chroot() { return 1; }
prepare_convert() { echo UNEXPECTED; }
convert_debian
''')
        self.assertEqual(result.returncode, 1)
        self.assertIn('cpio cannot safely extract', result.stdout)
        self.assertNotIn('UNEXPECTED', result.stdout)

    def test_install_and_initial_bootstrap_reject_broken_cpio(self):
        source = (ROOT/'share/eterbuild/korinf/install').read_text()
        for initial in ('', '1'):
            with self.subTest(initial=initial):
                result = self.run_shell(source, f'INITIALBOOTSTRAP={initial}\n'+'''
assert_var() { :; }
rhas() { return 1; }
convert_pkgreqs_to_target() { echo "$*"; }
quote_pkgname() { echo "$*"; }
warning() { echo "$*"; }
epm_stub() { echo true; }
run_in_chroot() {
    case "$2" in 'sh -s') cat >/dev/null; return 1 ;; esac
    return 0
}
BUILDNAME=eepm TARGETARCH=x86_64 BUILDARCH=x86_64 TARGETSRPM=dummy
PKGFORMAT=deb BUILDERHOME=dummy DISTRNAME=Ubuntu DISTRVERSION=22.04 EPMCMD=epm_stub
install_build_requires x86_64/Ubuntu/22.04
''')
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn('cpio cannot safely extract', result.stdout)

    @unittest.skipUnless(shutil.which('cpio'), 'cpio is unavailable')
    def test_real_cpio_round_trip(self):
        result = subprocess.run(['sh', str(PROBE)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_corrupted_absolute_link_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory)/'cpio'
            fake.write_text('''#!/bin/sh
if [ "$1" = -o ]; then cat; exit; fi
cat >/dev/null
mkdir -p nested
ln -s usr/bin/bash nested/absolute
ln -s missing nested/dangling
''')
            fake.chmod(0o755)
            env = dict(os.environ, PATH=directory+os.pathsep+os.environ['PATH'])
            result = subprocess.run(['sh', str(PROBE)], env=env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)

if __name__ == '__main__':
    unittest.main()
