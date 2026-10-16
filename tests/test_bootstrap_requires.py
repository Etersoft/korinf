"""Exercise BuildRequires handling without package installation or containers."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BootstrapRequires(unittest.TestCase):
    def test_i586_flags_do_not_depend_on_container_reported_architecture(self):
        source = (ROOT / 'share/eterbuild/korinf/install').read_text()
        harness = r"""
load_mod() { :; }
assert_var() { :; }
rhas() { return 1; }
convert_pkgreqs_to_target() { echo "$*"; }
quote_pkgname() { echo "$*"; }
warning() { :; }
epm_stub() { echo true; }
run_in_chroot() {
    case "$*" in *'tee /etc/rpm/'*) cat ;; esac
    return 0
}
BUILDNAME=rpm-build-altlinux-compat TARGETARCH=i586
TARGETSRPM=dummy PKGFORMAT=deb BUILDERHOME=dummy
DISTRNAME=Debian DISTRVERSION=12 EPMCMD=epm_stub INITIALBOOTSTRAP=1
install_build_requires Debian/12
"""
        for arch in ('i586', 'x86_64'):
            with self.subTest(buildarch=arch):
                result = subprocess.run(['bash', '-c', 'load_mod() { :; }\n' + source +
                    '\nKORINFDIR=' + str(ROOT / 'share/eterbuild') + '\nBUILDARCH=' + arch + '\n' + harness],
                    capture_output=True, text=True, check=True)
                self.assertIn('%optflags               -O2 -g -m32 -march=i586', result.stdout)

    def test_astra_dependency_install_failure_stops_build(self):
        source = (ROOT / 'share/eterbuild/korinf/install').read_text()
        harness = r'''
load_mod() { :; }
assert_var() { :; }
rhas() { return 1; }
convert_pkgreqs_to_target() { echo "$*"; }
quote_pkgname() { echo "$*"; }
warning() { :; }
epm_stub() { echo package-required-for-build; }
run_in_chroot() {
    case "$*" in *'--verbose install'*) return 42 ;; esac
}
BUILDNAME=wine-etersoft TARGETARCH=i586 BUILDARCH=x86_64
TARGETSRPM=dummy PKGFORMAT=deb BUILDERHOME=dummy
DISTRNAME=AstraLinuxSE DISTRVERSION=1.7 EPMCMD=epm_stub
install_build_requires AstraLinuxSE/1.7
'''
        result = subprocess.run(['bash'], text=True, capture_output=True,
            input='load_mod() { :; }\n' + source + '\nKORINFDIR=' +
                  str(ROOT / 'share/eterbuild') + '\n' + harness)
        self.assertEqual(result.returncode, 42, result.stderr)

    def test_bootstrap_installs_package_requires_except_initial_tools(self):
        source = (ROOT / 'share/eterbuild/korinf/install').read_text()
        harness = r'''
load_mod() { :; }
assert_var() { :; }
rhas() { [[ "$1" == *"$2"* ]]; }
convert_pkgreqs_to_target() { echo "$*"; }
quote_pkgname() { echo "$*"; }
warning() { :; }
epm_stub() { echo desktop-file-utils; }
run_in_chroot() { echo "$*"; }
BUILDNAME=wine-etersoft-winetricks TARGETARCH=i586 BUILDARCH=x86_64
TARGETSRPM=dummy PKGFORMAT=rpm BUILDERHOME=dummy DISTRNAME=Fedora
EPMCMD=epm_stub BOOTSTRAP=1
install_build_requires Fedora/41
'''
        for initial in ('', '1'):
            with self.subTest(initial=initial):
                result = subprocess.run(['bash'], text=True, capture_output=True,
                    input='load_mod() { :; }\n' + source + '\nKORINFDIR=' +
                          str(ROOT / 'share/eterbuild') + '\nINITIALBOOTSTRAP=' + initial + '\n' + harness,
                    check=True)
                self.assertEqual('install desktop-file-utils' in result.stdout, not initial)
                self.assertNotIn('--verbose --skip-installed install', result.stdout)


if __name__ == '__main__':
    unittest.main()
