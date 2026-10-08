"""Exercise BuildRequires handling without package installation or containers."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BootstrapRequires(unittest.TestCase):
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
                    input='load_mod() { :; }\n' + source + '\nINITIALBOOTSTRAP=' + initial + '\n' + harness,
                    check=True)
                self.assertEqual('install desktop-file-utils' in result.stdout, not initial)


if __name__ == '__main__':
    unittest.main()
