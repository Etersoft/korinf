import importlib.machinery
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('check_wine_install', str(ROOT/'tools/check-wine-install'))
spec = importlib.util.spec_from_loader(loader.name, loader)
check = importlib.util.module_from_spec(spec)
loader.exec_module(check)


class CheckWineInstall(unittest.TestCase):
    def test_only_published_binaries_are_selected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name in ['wine-etersoft-11.19-1.x86_64.rpm', 'wine-etersoft-full-11.19-1.x86_64.rpm',
                         'wine-etersoft-mono-11.3-1.noarch.rpm', 'wine-etersoft-11.19-1.src.rpm',
                         'eepm-3.0-1.noarch.rpm']:
                (root/name).touch()
            (root/'extra').mkdir()
            (root/'extra/wine-etersoft-devel-11.19-1.x86_64.rpm').touch()
            files, fmt, full = check.select_packages(root)
            self.assertEqual(len(files), 3)
            self.assertEqual(fmt, 'rpm')
            self.assertEqual(len(full), 1)
            script = check.install_script(files, fmt, full, root, 'https://example.org', 'VERIFIED')
            self.assertEqual(script.count('epm --auto install '), 1)
            self.assertIn('Base image already contains Wine', script)
            self.assertLess(script.index('rpm -qa'), script.index('epm --auto install'))
            self.assertLess(script.index('epm --auto install'), script.index('echo VERIFIED'))
            result = subprocess.run(['sh', '-n'], input=script, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_full_and_mixed_formats_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root/'wine-etersoft-11.19-1.x86_64.rpm').touch()
            with self.assertRaises(ValueError): check.select_packages(root)
            (root/'wine-etersoft-full_11.19-1_amd64.deb').touch()
            with self.assertRaises(ValueError): check.select_packages(root)

    def test_deb_installed_status_is_checked(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root/'wine-etersoft-full_11.19-1_amd64.deb').touch()
            files, fmt, full = check.select_packages(root)
            script = check.install_script(files, fmt, full, root, 'https://example.org', 'VERIFIED')
            self.assertIn('install ok installed', script)
            result = subprocess.run(['sh', '-n'], input=script, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_verification_cannot_save_or_reuse_wine_image(self):
        with patch.dict(os.environ, BOOTSTRAP='1', INSTALLREQUIREDPACKAGE='1', KORINFMODULE='wine-11.12'):
            env = check.verification_env()
            self.assertNotIn('BOOTSTRAP', env)
            self.assertNotIn('INSTALLREQUIREDPACKAGE', env)
            self.assertEqual(env['KORINFMODULE'], '')


if __name__ == '__main__':
    unittest.main()
