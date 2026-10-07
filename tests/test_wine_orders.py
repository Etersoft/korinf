"""Personal delivery tests use only temporary queues, profiles and FTP trees."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'buildapi'))
import main
import orders
import taskreader as tr
from fastapi.testclient import TestClient


class Orders(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        for name in ('sales', 'done', 'pub/11.6/WINE/x86_64/Ubuntu/24.04', 'pvt/11.6/WINE-Network', 'repo/etc/lists/x86_64', 'downloads'):
            (self.root / name).mkdir(parents=True)
        (self.root / 'pub/version.list').write_text('Стабильная:\t11.6\t*\n')
        (self.root / 'repo/etc/lists/x86_64/build').write_text('x86_64/Ubuntu/24.04\n#x86_64/Ubuntu/22.04\nall\n')
        for dist in ('Ubuntu/24.04', 'i586/Ubuntu/24.04'):
            (self.root / 'pub/11.6/WINE' / dist).mkdir(parents=True)
        (self.root / 'repo/etc/lists/legacy').write_text('Ubuntu/24.04\ni586/Ubuntu/24.04\n')
        (self.root / 'pub/11.6/distro.list').write_text('x86_64/Ubuntu/24.04\tUbuntu 24.04\n#x86_64/Ubuntu/22.04\nUbuntu/24.04\ni586/Ubuntu/24.04\nall\n')
        self.sample = self.root / 'done/20260910010000.ABCD-1234.abcdefghij.done'
        self.sample.write_text('PRODUCT="WINE@Etersoft"\nCOMPONENTNAME="WINE@Etersoft Enterprise"\nETERREGNUM="ABCD-1234"\nMAILTO="tester@etersoft.ru"\nFULLNAME="Тестировщик"\nTYPE_LICENSE="Corporate"\nCOUNT_LICENSE="1"\n# task done at today\n')
        self.patches = [patch.object(main, 'SALES', str(self.root / 'sales')), patch.object(main, 'DONE', str(self.root / 'done')),
            patch.dict(main.CFG, {'API_KEY': 'secret'}), patch.object(orders, 'ROOT', self.root / 'repo'),
            patch.object(orders, 'PUB', self.root / 'pub'), patch.object(orders, 'PVT', self.root / 'pvt'),
            patch.object(orders, 'DOWNLOADS', self.root / 'downloads'), patch.object(orders, 'STATE', self.root / 'state')]
        for p in self.patches: p.start()
        orders._cache.clear()
        self.client = TestClient(main.app)
        self.headers = {'X-API-Key': 'secret'}
        self.body = dict(principal='tester@ETERSOFT.RU', version='11.6', dist='x86_64/Ubuntu/24.04')

    def tearDown(self):
        for p in reversed(self.patches): p.stop()
        self.temp.cleanup()

    def get(self, path, principal='tester@ETERSOFT.RU'):
        return self.client.get('/api/wine/' + path, headers=self.headers, params={'principal': principal, 'version': '11.6'})

    def post(self, **changes):
        return self.client.post('/api/wine/orders', headers=self.headers, json=self.body | changes)

    def test_api_key_and_ownership(self):
        for path in ('versions', 'distributions', 'orders'):
            self.assertEqual(self.client.get('/api/wine/' + path).status_code, 401)
        self.assertEqual(self.client.post('/api/wine/orders', json=self.body).status_code, 401)
        self.assertEqual(self.post(principal='tester@EVIL.RU').status_code, 403)
        self.assertEqual(self.post(principal='other@ETERSOFT.RU').status_code, 404)
        self.assertEqual(self.post().status_code, 200)
        self.assertEqual(self.get('orders', 'other@ETERSOFT.RU').json(), [])

    def test_new_system_is_orderable_before_first_build(self):
        (self.root / 'pvt/11.6/WINE-Network').rmdir()
        listing = self.root / 'pub/11.6/distro.list'
        listing.write_text(listing.read_text() +
                          '\nXimperLinux/Deferred\t32 bit\n'
                          'x86_64/XimperLinux/Deferred\t64 bit\n'
                          'x86_64/XimperLinux/Deferred\tduplicate\n')
        self.assertFalse((self.root / 'pub/11.6/WINE/x86_64/XimperLinux/Deferred').exists())
        self.assertEqual(self.get('distributions').json(),
                         ['x86_64/Ubuntu/24.04', 'x86_64/XimperLinux/Deferred'])
        response = self.post(dist='x86_64/XimperLinux/Deferred')
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(self.post(dist='XimperLinux/Deferred').status_code, 400)

    def test_catalog_and_validation(self):
        self.assertEqual(self.get('versions').json(), [dict(version='11.6', label='Стабильная', default=True)])
        self.assertEqual(self.get('distributions').json(), ['x86_64/Ubuntu/24.04'])
        for field, value in [('version', '../11.6'), ('dist', 'all'), ('dist', 'Ubuntu/24.04'), ('dist', 'i586/Ubuntu/24.04'), ('dist', 'x86_64/Ubuntu/22.04'), ('dist', '$(touch /tmp/x)')]:
            self.assertEqual(self.post(**{field: value}).status_code, 400)
        self.assertEqual(list((self.root / 'sales').iterdir()), [])

    def test_safe_task_and_deduplication(self):
        first = self.post().json()
        self.assertEqual(self.post().json()['taskid'], first['taskid'])
        path = self.root / 'sales' / (first['taskid'] + '.task')
        fields = tr.parse_file(str(path))[0]
        self.assertEqual(fields['MAILTO'], 'tester@etersoft.ru')
        self.assertEqual(fields['ETERREGNUM'], 'ABCD-1234')
        self.assertEqual(fields['CLEAR_FAILED_ON_RESTART'], '1')
        self.assertEqual(fields['WEB_ORDER_USER'], 'tester@etersoft.ru')
        self.assertNotIn('PACKAGE', fields)
        subprocess.run(['bash', '-n', str(path)], check=True)
        subprocess.run(['bash', '-c', '. "$1"; test "$MAILTO" = tester@etersoft.ru && test "$DIST" = x86_64/Ubuntu/24.04', 'test', str(path)], check=True)
        self.assertEqual(len(list((self.root / 'sales').glob('*.task'))), 1)

    def test_ready_failed_and_expired(self):
        record = self.post().json()
        taskid = record['taskid']
        task = self.root / 'sales' / (taskid + '.task')
        rel = 'ABCD-random1234/Network-11.6/x86_64/Ubuntu/24.04'
        task.write_text(task.read_text() + 'WEB_DOWNLOAD_REL="' + rel + '"\n')
        directory = self.root / 'downloads' / rel
        directory.mkdir(parents=True)
        self.assertEqual(self.get('orders').json()[0]['status'], 'queued')
        failed = task.with_suffix('.task.failed')
        task.rename(failed)
        self.assertEqual(self.get('orders').json()[0]['status'], 'failed')
        failed.rename(task)
        for name in ('wine-etersoft.lic', 'wine-etersoft-install.sh', 'wine-etersoft-install.sha256'):
            (directory / name).write_text('content')
        self.assertEqual(self.get('orders').json()[0]['status'], 'queued')
        (directory / ('.order-' + taskid + '.ready')).touch()
        ready = self.get('orders').json()[0]
        self.assertEqual(ready['status'], 'ready')
        self.assertTrue(ready['install_url'].startswith('https://download.etersoft.ru/W@E/ABCD-random1234/'))
        task.rename(self.root / 'done' / (taskid + '.done'))
        (directory / 'wine-etersoft.lic').unlink()
        self.assertEqual(self.get('orders').json()[0]['status'], 'expired')

    def test_profile_special_characters_are_literal(self):
        marker = self.root / 'must-not-exist'
        value = 'ООО "Тест" C:\\Docs $HOME $(touch ' + str(marker) + ')'
        self.sample.write_text(self.sample.read_text() + "OWNER='" + value + "'\n")
        response = self.post()
        self.assertEqual(response.status_code, 200, response.text)
        task = self.root / 'sales' / (response.json()['taskid'] + '.task')
        self.assertEqual(tr.parse_file(str(task))[0]['OWNER'], value)
        result = subprocess.run(['bash', '-c', '. "$1"; printf %s "$OWNER"', 'test', str(task)],
                                check=True, capture_output=True, text=True)
        self.assertEqual(result.stdout, value)
        self.assertFalse(marker.exists())

    def test_shell_value_roundtrip(self):
        marker = self.root / 'must-not-exist'
        values = ['ООО "Компания"', "O'Reilly", r'C:\new\test', '$HOME',
                  '`touch ' + str(marker) + '`', '\\"', '\\', '']
        for value in values:
            with self.subTest(value=value):
                text = 'OWNER=' + orders.shell_value(value) + '\n'
                self.assertEqual(tr.parse_text(text)[0]['OWNER'], value)
                task = self.root / 'literal.task'
                task.write_text(text)
                result = subprocess.run(['bash', '-c', '. "$1"; printf %s "$OWNER"', 'test', str(task)],
                                        check=True, capture_output=True, text=True)
                self.assertEqual(result.stdout, value)
        self.assertFalse(marker.exists())
        for value in ('bad\nline', 'bad\rline', 'bad\x00byte'):
            with self.assertRaises(orders.HTTPException):
                orders.shell_value(value)



if __name__ == '__main__': unittest.main()
