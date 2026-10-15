"""Preflight and no-build guard tests: no containers, mail or real FTP writes."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ReadyOrders(unittest.TestCase):
    def shell(self, script, tmp):
        return subprocess.run(['bash', '-c', script], cwd=tmp, capture_output=True, text=True,
                              env=dict(os.environ, REPO=str(ROOT), TESTROOT=str(tmp)), timeout=10)

    def test_product_preflight_has_no_delivery_side_effects(self):
        for product, function in [('wine-etersoft', 'build_wine_etersoft'),
                                  ('rx', 'build_rx'), ('crypto', 'build_crypto')]:
            for license_only in ('', '1'):
                with self.subTest(product=product, license_only=license_only), tempfile.TemporaryDirectory() as tmp:
                    script = '''
AROBOTDIR=$REPO/robot
. "$AROBOTDIR/funcs/message"
. "$AROBOTDIR/products/''' + product + '''"
KORINF_CHECK_ONLY=1
KORINF_DEFER_FILE=$TESTROOT/defer
PROJECTVERSION=11-testing
PROJECTNAME=WINE@Etersoft
DOWNLOADDIR=Test/11-testing
COMPONENTNAME=WINE@Etersoft
TARGETDIRNAME=test-only
DIST=x86_64/Ubuntu/22.04
PKGTYPE=deb
TYPE=Network
LICENSEONLY=''' + license_only + '''
get_product_type() { echo Network; }
check_dist() { :; }
rhas() { echo "$1" | grep -Eq "$2"; }
check_and_refresh_component() { echo "check $3"; }
check_and_refresh_package() { echo "check $2"; }
assert_present_package() { :; }
estrlist() { echo WINE@Etersoft; }
find() { :; }
forbidden() { echo "Unexpected side effect: $*" >&2; exit 99; }
mkdir() { forbidden mkdir; }
rm() { forbidden rm; }
cp() { forbidden cp; }
touch() { forbidden touch; }
mutt() { forbidden mutt; }
mktemp() { forbidden mktemp; }
create_license_dir() { forbidden license; }
create_ftp_dir() { forbidden ftp; }
mail_wine_etersoft_license() { forbidden mail; }
''' + function
                    result = self.shell(script, tmp)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(list(Path(tmp).iterdir()), [])
                    if not license_only:
                        self.assertIn('check ', result.stdout)

    def test_stale_packages_defer_without_build_or_status_changes(self):
        for mode in ('KORINF_CHECK_ONLY', 'KORINF_NO_BUILD'):
            for method in ('check_and_refresh_component bin-wine "$TESTROOT" wine-etersoft 11-testing',
                           'check_and_refresh_package "$TESTROOT" eepm'):
                with self.subTest(mode=mode, method=method), tempfile.TemporaryDirectory() as tmp:
                    script = '''
AROBOTDIR=$REPO/robot
kormod() { :; }
. "$AROBOTDIR/funcs/message"
. "$AROBOTDIR/funcs/build"
''' + mode + '''=1
KORINF_DEFER_FILE=$TESTROOT/defer
DIST=Ubuntu/22.04
assert_var() { :; }
get_sources_dir() { echo "$TESTROOT"; }
check_if_updated() { return 1; }
set_autobuild_failed() { exit 99; }
''' + method + '\nexit 99\n'
                    result = self.shell(script, tmp)
                    self.assertEqual(result.returncode, 75, result.stdout + result.stderr)
                    self.assertTrue((Path(tmp) / 'defer').exists())

    def test_current_package_passes_without_clearing_failure_markers(self):
        with tempfile.TemporaryDirectory() as tmp:
            script = '''
AROBOTDIR=$REPO/robot
kormod() { :; }
. "$AROBOTDIR/funcs/message"
. "$AROBOTDIR/funcs/build"
KORINF_CHECK_ONLY=1
DIST=Ubuntu/22.04
assert_var() { :; }
get_src_package() { echo "$TESTROOT/src"; }
get_bin_package() { echo "$TESTROOT/bin"; }
clear_restart_build_status() { exit 99; }
check_pkg_integrity() { return 0; }
check_if_updated wine-etersoft "$TESTROOT" "$TESTROOT"
'''
            source = Path(tmp) / 'src'
            source.touch()
            os.utime(source, (1, 1))
            (Path(tmp) / 'bin').touch()
            result = self.shell(script, tmp)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_failure_in_subshell_is_not_lost(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = self.shell('''
AROBOTDIR=$REPO/robot
. "$AROBOTDIR/funcs/message"
KORINF_DEFER_FILE=$TESTROOT/defer
KORINF_CHECK_ONLY=1
(fatal "missing package")
task_require_ready
exit 99
''', tmp)
            self.assertEqual(result.returncode, 75, result.stderr)


if __name__ == '__main__':
    unittest.main()
