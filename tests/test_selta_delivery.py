"""SELTA@Etersoft delivery (robot/products/selta) on a temporary pvt tree: no mail, builds or real FTP."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
DIST = 'x86_64/ALTLinux/Sisyphus'
RPM = 'selta-server-1.1.6-alt1.noarch.rpm'
DEB_DIST = 'x86_64/Debian/12'
DEB = 'selta-server_1.1.6-alt1_all.deb'
MCHAR = 'postgresql-mchar_2.2.1-alt1_amd64.deb'

STUBS = '''
AROBOTDIR=$REPO/robot
. "$AROBOTDIR/funcs/message"
. "$AROBOTDIR/funcs/common"
. "$AROBOTDIR/products/common"
. "$AROBOTDIR/products/selta"
SELTA_PVT=$TESTROOT/pvt
KORINF_DEFER_FILE=$TESTROOT/defer
PROJECTVERSION=1.1.6
DOWNLOADDIR=SELTA@Etersoft/last
COMPONENTNAME=SELTA@Etersoft
PRODUCT="SELTA@Etersoft 1.1 (базовая лицензия)"
FULLNAME="Иванов Иван Иванович"
TYPE_LICENSE=Base
DATE_START={date_start}
ETERREGNUM=0D23-A26B
TARGETDIRNAME=0D23-test
MPROTO=https
DOWNLOADDOMAIN=download.etersoft.ru
DIST={dist}
LICENSEONLY={license_only}
ALOGDIR=$TESTROOT/log
check_dist() {{ :; }}
check_and_refresh_component() {{ echo "check $1 $3"; }}
assert_present_package() {{ [ -r "$(echo $1/$2[-_][0-9]*)" ] || fatal "no $2 in $1"; }}
get_dear_from_fio() {{ echo Иван; }}
make_temp_file() {{ echo $TESTROOT/mail; }}
create_license() {{ echo "DATE_START=$DATE_START" > "$1"; }}
mutt() {{ cat > $TESTROOT/sent; echo "$@" > $TESTROOT/sent.args; }}
'''


class SeltaDelivery(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        version = self.root / 'pvt' / 'SELTA@Etersoft' / '1.1.6'
        (version / 'Windows').mkdir(parents=True)
        (version / DIST).mkdir(parents=True)
        (version.parent / 'last').symlink_to('1.1.6')
        self.windows = version / 'Windows'
        for name in ('selta', 'seltaEng'):
            (version / 'Windows' / f'{name}-1.1.6-eter1.x86.msi').write_text(name)
            (version / 'Windows' / f'{name}.msi').symlink_to(f'{name}-1.1.6-eter1.x86.msi')
        (version / DIST / RPM).write_text('rpm')
        self.download = self.root / 'download'

    def tearDown(self):
        self.tmp.cleanup()

    def run_selta(self, extra='', dist=DIST, license_only='', date_start='01/03/2026'):
        script = STUBS.format(dist=dist, license_only=license_only, date_start=date_start) + extra + '''
create_ftp_dir() { export FTPDIR=$TESTROOT/download/$PROJECTVERSION; mkdir -p $FTPDIR; }
build_selta
'''
        return subprocess.run(['bash', '-c', script], cwd=self.root, capture_output=True, text=True, timeout=20,
                              env=dict(os.environ, REPO=str(ROOT), TESTROOT=str(self.root)))

    def test_delivery(self):
        r = self.run_selta()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('check bin-selta selta-server', r.stdout)
        ftp = self.download / '1.1.6'
        self.assertEqual((ftp / 'Windows' / 'selta.msi').read_text(), 'selta')
        self.assertEqual((ftp / 'Windows' / 'seltaEng.msi').read_text(), 'seltaEng')
        self.assertFalse((ftp / 'Windows' / 'selta.msi').is_symlink())
        self.assertTrue((ftp / DIST / RPM).exists())
        self.assertTrue((ftp / 'selta.lic').exists())
        mail = (self.root / 'sent').read_text()
        url = 'https://download.etersoft.ru/pub/download/SELTA@Etersoft/0D23-test/1.1.6'
        for link in ('/Windows/selta.msi', '/Windows/seltaEng.msi', '/selta.lic', f'/{DIST}/{RPM}'):
            self.assertIn(url + link, mail)
        self.assertIn('selta-pg-setup init', mail)
        self.assertNotIn('postgre-etersoft', mail)
        self.assertIn('0D23-A26B: Сборка SELTA@Etersoft 1.1.6', (self.root / 'sent.args').read_text())
        # no 64-bit driver yet
        self.assertFalse((ftp / 'Windows' / 'selta64.msi').exists())
        self.assertNotIn('64-битный драйвер', mail)
        self.assertIn('после удаления прежней', mail)

    def add_x64(self, names=('selta', 'seltaEng')):
        for name in names:
            (self.windows / f'{name}-1.1.6-eter1.x64.msi').write_text(name + '64')
            (self.windows / f'{name}64.msi').symlink_to(f'{name}-1.1.6-eter1.x64.msi')

    def test_delivery_x64(self):
        self.add_x64()
        r = self.run_selta()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        ftp = self.download / '1.1.6' / 'Windows'
        self.assertEqual((ftp / 'selta.msi').read_text(), 'selta')
        self.assertEqual((ftp / 'selta64.msi').read_text(), 'selta64')
        self.assertEqual((ftp / 'seltaEng64.msi').read_text(), 'seltaEng64')
        mail = (self.root / 'sent').read_text()
        self.assertIn('64-битный драйвер', mail)
        self.assertIn('/0D23-test/1.1.6/Windows/seltaEng64.msi', mail)
        self.assertIn('можно установить на один компьютер', mail)

    def test_half_x64_fails(self):
        self.add_x64(('selta',))
        r = self.run_selta()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('Only selta64.msi', r.stderr + r.stdout)
        self.assertFalse((self.root / 'sent').exists())

    def test_missing_msi_fails(self):
        (self.root / 'pvt/SELTA@Etersoft/1.1.6/Windows/seltaEng.msi').unlink()
        r = self.run_selta()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('Missed seltaEng.msi', r.stderr + r.stdout)
        self.assertFalse((self.root / 'sent').exists())

    def test_license_only(self):
        r = self.run_selta(dist='ANY', license_only='1')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(sorted(p.name for p in (self.download / '1.1.6').iterdir()), ['selta.lic'])
        self.assertNotIn('check ', r.stdout)
        self.assertIn('Лицензия для продукта SELTA@Etersoft 1.1.6', (self.root / 'sent.args').read_text())

    def test_check_only_has_no_side_effects(self):
        r = self.run_selta(extra='''
KORINF_CHECK_ONLY=1
forbidden() { echo "Unexpected side effect: $*" >&2; exit 99; }
create_license_dir() { forbidden license; }
mutt() { forbidden mutt; }
cp() { forbidden cp; }
''')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('check bin-selta selta-server', r.stdout)
        self.assertFalse(self.download.exists())

    def test_date_start_is_a_day_earlier(self):
        # the driver compares DATE_START with the UTC date, the order date is Moscow
        for start, lic in (('01/03/2026', '28/02/2026'), ('01/01/2027', '31/12/2026'), ('08/11/2026', '07/11/2026')):
            r = self.run_selta(date_start=start)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertEqual((self.download / '1.1.6' / 'selta.lic').read_text().strip(), 'DATE_START=' + lic)
        r = self.run_selta(license_only='1', date_start='08/11/2026')
        self.assertEqual((self.download / '1.1.6' / 'selta.lic').read_text().strip(), 'DATE_START=07/11/2026')

    def test_wrong_date_start_fails(self):
        r = self.run_selta(date_start='2026-11-08')
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('Wrong DATE_START', r.stdout + r.stderr)

    def add_debian(self, mchar=True):
        d = self.windows.parent / DEB_DIST
        d.mkdir(parents=True)
        (d / DEB).write_text('deb')
        if mchar:
            (d / MCHAR).write_text('mchar')
        return d

    def test_delivery_debian_with_mchar(self):
        self.add_debian()
        r = self.run_selta(dist=DEB_DIST)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('check bin-selta postgresql-mchar', r.stdout)
        ftp = self.download / '1.1.6' / DEB_DIST
        self.assertTrue((ftp / DEB).exists())
        self.assertEqual((ftp / MCHAR).read_text(), 'mchar')
        mail = (self.root / 'sent').read_text()
        url = 'https://download.etersoft.ru/pub/download/SELTA@Etersoft/0D23-test/1.1.6/' + DEB_DIST
        self.assertIn(f'{url}/{DEB}', mail)
        self.assertIn(f'{url}/{MCHAR}', mail)
        self.assertIn('epm play postgrespro-1c', mail)
        self.assertNotIn('PostgreSQL для 1C в системе', mail)

    def test_alt_has_no_mchar(self):
        r = self.run_selta()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn('postgresql-mchar', r.stdout)
        mail = (self.root / 'sent').read_text()
        self.assertNotIn('postgresql-mchar', mail)
        self.assertIn('PostgreSQL для 1C в системе', mail)

    def test_osnova_has_no_mchar(self):
        d = self.windows.parent / 'x86_64/OSnovaLinux/3.0'
        d.mkdir(parents=True)
        (d / DEB).write_text('deb')
        r = self.run_selta(dist='x86_64/OSnovaLinux/3.0')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn('postgresql-mchar', r.stdout)
        mail = (self.root / 'sent').read_text()
        self.assertNotIn('postgresql-mchar', mail)
        self.assertIn('PostgreSQL для 1C в системе', mail)

    def test_astra18_has_no_mchar(self):
        d = self.windows.parent / 'x86_64/AstraLinuxSE/1.8'
        d.mkdir(parents=True)
        (d / DEB).write_text('deb')
        r = self.run_selta(dist='x86_64/AstraLinuxSE/1.8')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn('postgresql-mchar', r.stdout)
        mail = (self.root / 'sent').read_text()
        self.assertNotIn('postgresql-mchar', mail)
        self.assertIn('PostgreSQL для 1C в системе', mail)

    def test_missing_mchar_fails(self):
        self.add_debian(mchar=False)
        r = self.run_selta(dist=DEB_DIST)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('postgresql-mchar', r.stdout + r.stderr)
        self.assertFalse((self.root / 'sent').exists())


if __name__ == '__main__':
    unittest.main()
