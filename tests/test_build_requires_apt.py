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


if __name__ == '__main__':
    unittest.main()
