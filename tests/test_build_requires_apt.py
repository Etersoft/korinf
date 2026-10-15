"""Check that optional apt dependencies are disabled only for BuildRequires."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BuildRequiresApt(unittest.TestCase):
    def test_apt_options_are_preserved_and_scoped(self):
        source = (ROOT / 'share/eterbuild/korinf/install').read_text()
        harness = r'''
load_mod() { :; }
assert_var() { :; }
rhas() { return 1; }
convert_pkgreqs_to_target() { echo "$*"; }
quote_pkgname() { echo "$*"; }
warning() { :; }
epm_stub() { echo test-build-requirement; }
epm() { printf 'epm:%s|%s\n' "$APTOPTIONS" "$*"; }
export -f epm
export APTOPTIONS='--no-remove -o Debug::pkgProblemResolver=true'
run_in_chroot() {
    case "$2" in *epm*) bash -c "$2" ;; esac
}
BUILDNAME=test-package TARGETARCH=x86_64 BUILDARCH=x86_64
TARGETSRPM=dummy BUILDERHOME=dummy DISTRNAME=Ubuntu DISTRVERSION=22.04
EPMCMD=epm_stub
install_build_requires x86_64/Ubuntu/22.04
printf 'parent:%s\n' "$APTOPTIONS"
'''
        for pkgformat in ('deb', 'rpm'):
            with self.subTest(pkgformat=pkgformat):
                result = subprocess.run(['bash'], text=True, capture_output=True,
                    input='load_mod() { :; }\n' + source + '\nPKGFORMAT=' + pkgformat + '\n' + harness)
                self.assertEqual(result.returncode, 0, result.stderr)
                calls = [line for line in result.stdout.splitlines() if line.startswith('epm:')]
                installs = [line for line in calls if '--verbose install' in line]
                self.assertEqual(len(installs), 2)
                for line in installs:
                    self.assertIn('--no-remove -o Debug::pkgProblemResolver=true', line)
                    self.assertEqual('--no-install-recommends' in line, pkgformat == 'deb')
                for line in calls:
                    if '--verbose install' not in line:
                        self.assertNotIn('--no-install-recommends', line)
                self.assertIn('parent:--no-remove -o Debug::pkgProblemResolver=true\n', result.stdout)

    def test_initial_bootstrap_updates_before_install_and_stops_on_failure(self):
        source = (ROOT / 'share/eterbuild/korinf/install').read_text()
        harness = r'''
load_mod() { :; }
assert_var() { :; }
rhas() { return 1; }
convert_pkgreqs_to_target() { echo "$*"; }
quote_pkgname() { echo "$*"; }
warning() { :; }
epm_stub() { echo 'apt-get install dependencies'; }
run_in_chroot() {
    printf 'call:%s\n' "$2"
    case "$2" in *' update') return "$UPDATE_RC";; esac
    return 0
}
BUILDNAME=eepm TARGETARCH=i586 BUILDARCH=i586
TARGETSRPM=dummy BUILDERHOME=dummy DISTRNAME=Debian DISTRVERSION=12
INITIALBOOTSTRAP=1 PKGFORMAT=deb EPMCMD=epm_stub
install_build_requires Debian/12
'''
        for code in (0, 42):
            with self.subTest(update_code=code):
                result = subprocess.run(['bash'], text=True, capture_output=True,
                    input='load_mod() { :; }\n' + source + '\nKORINFDIR=' + str(ROOT / 'share/eterbuild') +
                          '\nUPDATE_RC=' + str(code) + '\n' + harness)
                self.assertEqual(result.returncode, code, result.stderr)
                calls = [line for line in result.stdout.splitlines() if line.startswith('call:')]
                self.assertIn(' update', calls[0])
                installs = [line for line in calls if 'install dependencies' in line]
                self.assertEqual(len(installs), 1 if code == 0 else 0)


if __name__ == '__main__':
    unittest.main()
