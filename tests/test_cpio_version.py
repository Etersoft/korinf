"""Reject old cpio before alien; propagate init upgrade failures."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]

class CpioVersion(unittest.TestCase):
    def run_shell(self, source, body):
        return subprocess.run(['bash'], input='load_mod() { :; }; kormod() { :; }\n'+source+'\n'+body, text=True, capture_output=True)

    def test_conversion_stops_before_preparing_packages(self):
        source = (ROOT/'share/eterbuild/korinf/converts/deb').read_text()
        body = '''
assert_var() { :; }
warning() { echo "$*"; }
run_in_chroot() { return 1; }
prepare_convert() { echo UNEXPECTED; }
convert_debian
'''
        result = self.run_shell(source, body)
        self.assertEqual(result.returncode, 1)
        self.assertIn('cpio >= 2.15', result.stdout)
        self.assertNotIn('UNEXPECTED', result.stdout)

    def test_init_propagates_assure_failure(self):
        source = (ROOT/'share/eterbuild/korinf/install').read_text()
        body = '''
assert_var() { :; }
rhas() { return 1; }
convert_pkgreqs_to_target() { echo "$*"; }
quote_pkgname() { echo "$*"; }
warning() { :; }
epm_stub() { echo build-requirement; }
run_in_chroot() {
    case "$*" in *'assure cpio cpio 2.15'*) return 42 ;; esac
    return 0
}
BUILDNAME=test TARGETARCH=x86_64 BUILDARCH=x86_64 TARGETSRPM=dummy
PKGFORMAT=deb BUILDERHOME=dummy DISTRNAME=Ubuntu DISTRVERSION=22.04 EPMCMD=epm_stub
install_build_requires x86_64/Ubuntu/22.04
'''
        result = self.run_shell(source, body)
        self.assertEqual(result.returncode, 42, result.stderr)

    def test_bootstrap_version_command_keeps_dpkg_format(self):
        source = (ROOT/'share/eterbuild/korinf/install').read_text()
        body = '''
assert_var() { :; }
rhas() { return 1; }
convert_pkgreqs_to_target() { echo "$*"; }
quote_pkgname() { echo "$*"; }
warning() { :; }
epm_stub() { echo true; }
run_in_chroot() { printf '%s\\n' "$2"; }
BUILDNAME=eepm TARGETARCH=x86_64 BUILDARCH=x86_64 TARGETSRPM=dummy
PKGFORMAT=deb BUILDERHOME=dummy DISTRNAME=Ubuntu DISTRVERSION=22.04 EPMCMD=epm_stub INITIALBOOTSTRAP=1
install_build_requires x86_64/Ubuntu/22.04
'''
        result = self.run_shell(source, body)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("-f='${Version}'", result.stdout)
        self.assertNotIn('assure', result.stdout)

if __name__ == '__main__':
    unittest.main()
