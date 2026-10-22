"""Stable CRYPTO releases select the matching architecture's Wine provider."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CryptoToolchain(unittest.TestCase):
    def test_provider_selection(self):
        for target, version, module, package in [
            ('x86_64/ALTLinux/Sisyphus', '0.4', 'wine-11.0', 'wine-etersoft-devel-tools'),
            ('i586/ALTLinux/Sisyphus', '0.4', 'wine-11.0', 'wine32-etersoft-devel-tools'),
            ('ALTLinux/p10', '0.5', 'wine-11.0', 'wine32-etersoft-devel-tools'),
            ('x86_64/ALTLinux/Sisyphus', '0.5-9', 'wine-9.0', ''),
        ]:
            with self.subTest(target=target, version=version):
                result = subprocess.run(['bash', '-c', '''
                    unset ETERBUILD_HASHER_BUILD_PACKAGES
                    . ./functions
                    NAME=wine-etersoft-cpcsp_proxy
                    set_ver "$@"
                    printf '%s\n%s\n' "$KORINFMODULE" "$ETERBUILD_HASHER_BUILD_PACKAGES"
                ''', './wine-etersoft-cpcsp_proxy.sh', target, version],
                    cwd=ROOT / 'bin-crypto', capture_output=True, text=True, check=True)
                self.assertEqual(result.stdout, module + '\n' + package + '\n')

    def test_other_crypto_components_keep_their_build_environment(self):
        result = subprocess.run(['bash', '-c', '''
            unset ETERBUILD_HASHER_BUILD_PACKAGES
            . ./functions
            NAME=ecryptomgr
            set_ver x86_64/ALTLinux/Sisyphus 0.4
            test -z "$ETERBUILD_HASHER_BUILD_PACKAGES"
        ''', './ecryptomgr.sh'], cwd=ROOT / 'bin-crypto', capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
