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
            patch.object(orders, 'ETERSOFT_PUB', self.root / 'etersoft/pub'), patch.object(orders, 'ETERSOFT_PVT', self.root / 'etersoft/pvt'),
            patch.object(orders, 'DOWNLOAD_ROOT', self.root / 'etersoft/download'), patch.object(orders, 'STATE', self.root / 'state')]
        # WINE@Etersoft is a product as the others: <root>/WINE@Etersoft
        for name, target in (('pub', 'pub'), ('pvt', 'pvt'), ('download', 'downloads')):
            (self.root / 'etersoft' / name).mkdir(parents=True)
            (self.root / 'etersoft' / name / 'WINE@Etersoft').symlink_to(self.root / target)
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



class ProductOrders(unittest.TestCase):
    """RX@Etersoft and CRYPTO@Etersoft orders on temporary trees."""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        r = self.root = Path(self.temp.name)
        for name in ('sales', 'done', 'downloads'):
            (r / name).mkdir(parents=True)
        for product, version, label in (('RX@Etersoft', '1.10', 'Стабильная'), ('CRYPTO@Etersoft', '0.5', 'Стабильная')):
            (r / 'pub' / product / version).mkdir(parents=True)
            (r / 'pub' / product / version / 'distro.list').write_text('x86_64/ALTLinux/p10\tAlt\nALTLinux/p10\n')
            (r / 'pvt' / product / version).mkdir(parents=True)
            (r / 'pub' / product / 'version.list').write_text(f'# версии\n{label}:\t{version}\t*\nБета-версия:\tunstable\n')
        (r / 'done/20260917200448.CAB8-E604.8hxufzhzld.done').write_text(
            "PRODUCT='RX@Etersoft (лицензия на 1 пользователя)'\nCOMPONENTNAME='RX@Etersoft'\nETERREGNUM='CAB8-E604'\n"
            "MAILTO='tester@etersoft.ru'\nFULLNAME='Тестировщик'\nTYPE_LICENSE='Corporate'\nDIST='x86_64/ALTLinux/Sisyphus'\n"
            "DOWNLOADDIR='RX@Etersoft/1.9'\nPROJECTVERSION='1.9'\n# task done at today\n")
        self.patches = [patch.object(main, 'SALES', str(r / 'sales')), patch.object(main, 'DONE', str(r / 'done')),
                        patch.dict(main.CFG, {'API_KEY': 'secret'}),
                        patch.object(orders, 'ETERSOFT_PUB', r / 'pub'), patch.object(orders, 'ETERSOFT_PVT', r / 'pvt'),
                        patch.object(orders, 'DOWNLOAD_ROOT', r / 'downloads'), patch.object(orders, 'STATE', r / 'state')]
        for p in self.patches:
            p.start()
        orders._cache.clear()
        self.client = TestClient(main.app)
        self.headers = {'X-API-Key': 'secret'}

    def tearDown(self):
        for p in reversed(self.patches):
            p.stop()
        self.temp.cleanup()

    # the product paths; class Orders runs the deprecated /api/wine/ ones
    def order(self, product='RX@Etersoft', version='1.10', principal='tester@ETERSOFT.RU'):
        return self.client.post('/api/orders', headers=self.headers,
                                json=dict(principal=principal, version=version, dist='x86_64/ALTLinux/p10', product=product))

    def test_catalog(self):
        r = self.client.get('/api/orders/versions', headers=self.headers).json()
        self.assertEqual(r, [dict(product='RX@Etersoft', version='1.10', label='Стабильная', default=True),
                             dict(product='CRYPTO@Etersoft', version='0.5', label='Стабильная', default=True)])
        d = self.client.get('/api/orders/distributions', headers=self.headers,
                            params=dict(principal='tester@ETERSOFT.RU', version='1.10', product='RX@Etersoft'))
        self.assertEqual(d.json(), ['x86_64/ALTLinux/p10'])
        bad = self.client.get('/api/orders/distributions', headers=self.headers,
                              params=dict(principal='tester@ETERSOFT.RU', version='1.10', product='SELTA@Etersoft'))
        self.assertEqual(bad.status_code, 400)

    def test_enqueue(self):
        r = self.order()
        self.assertEqual(r.status_code, 200, r.text)
        data = r.json()
        self.assertEqual((data['product'], data['version'], data['status']), ('RX@Etersoft', '1.10', 'queued'))
        fields, _, _ = tr.parse_file(r.json() and str(self.root / 'sales' / (data['taskid'] + '.task')))
        self.assertEqual(fields['COMPONENTNAME'], 'RX@Etersoft')
        self.assertEqual(fields['DOWNLOADDIR'], 'RX@Etersoft/1.10')
        self.assertEqual((fields['PROJECTVERSION'], fields['DIST'], fields['ETERREGNUM']), ('1.10', 'x86_64/ALTLinux/p10', 'CAB8-E604'))
        self.assertEqual(self.order().json()['taskid'], data['taskid'])
        history = self.client.get('/api/orders', headers=self.headers, params=dict(principal='tester@ETERSOFT.RU')).json()
        self.assertEqual([h['product'] for h in history], ['RX@Etersoft'])

    def test_profile_of_the_same_product(self):
        self.assertEqual(self.order(product='CRYPTO@Etersoft', version='0.5').status_code, 404)
        self.assertEqual(self.order(version='1.9').status_code, 400)
        self.assertEqual(list((self.root / 'sales').glob('*.task')), [])

    def ready(self, product, version, files):
        taskid = self.order(product, version).json()['taskid']
        task = self.root / 'sales' / (taskid + '.task')
        rel = 'CAB8-abc/' + version
        task.write_text(task.read_text() + f'WEB_DOWNLOAD_REL="{rel}"\n# task done at today\n')
        done = self.root / 'done' / (taskid + '.done')
        task.rename(done)
        directory = self.root / 'downloads' / product / 'CAB8-abc' / version
        directory.mkdir(parents=True)
        for name in files + ['.order-' + taskid + '.ready']:
            (directory / name).touch()
        return self.client.get('/api/orders', headers=self.headers, params=dict(principal='tester@ETERSOFT.RU')).json()[0]

    def test_rx_ready(self):
        status = self.ready('RX@Etersoft', '1.10', ['rx-etersoft.lic'])
        self.assertEqual(status['status'], 'ready')
        self.assertEqual(status['download_url'], 'https://download.etersoft.ru/pub/download/RX%40Etersoft/CAB8-abc/1.10/')
        self.assertIsNone(status['install_url'])

    def test_rx_without_license_is_not_ready(self):
        self.assertEqual(self.ready('RX@Etersoft', '1.10', [])['status'], 'expired')

    def test_crypto_ready(self):
        (self.root / 'done/20260917200449.CAB8-E604.8hxufzhzle.done').write_text(
            "PRODUCT='CRYPTO@Etersoft'\nCOMPONENTNAME='CRYPTO@Etersoft'\nETERREGNUM='CAB8-E604'\n"
            "MAILTO='tester@etersoft.ru'\nFULLNAME='Тестировщик'\nTYPE_LICENSE='Corporate'\n# task done at today\n")
        status = self.ready('CRYPTO@Etersoft', '0.5', [])
        self.assertEqual((status['status'], status['product']), ('ready', 'CRYPTO@Etersoft'))


class RobotOrderHooks(unittest.TestCase):
    def run_hooks(self, task_text):
        with tempfile.TemporaryDirectory() as tmp:
            task = Path(tmp) / '20261008120000.CAB8-E604.abcdefghij.task'
            task.write_text(task_text)
            delivery = Path(tmp) / 'delivery'
            delivery.mkdir()
            script = (f'fatal() {{ echo "$*"; exit 1; }}; . {ROOT}/robot/products/common; TASK={task}; '
                      f'WEB_ORDER_ID=$(sed -n "s/^WEB_ORDER_ID=//p" {task}); '
                      f'order_delivery "CAB8-xyz/1.10"; order_ready {delivery}')
            subprocess.run(['bash', '-c', script], check=True)
            return task.read_text(), sorted(p.name for p in delivery.iterdir())

    def test_order_task(self):
        text, files = self.run_hooks('WEB_ORDER_ID=20261008120000.CAB8-E604.abcdefghij\n')
        self.assertIn('WEB_DOWNLOAD_REL="CAB8-xyz/1.10"', text)
        self.assertEqual(files, ['.order-20261008120000.CAB8-E604.abcdefghij.ready'])

    def test_other_task_untouched(self):
        text, files = self.run_hooks('COMPONENTNAME="RX@Etersoft"\n')
        self.assertNotIn('WEB_DOWNLOAD_REL', text)
        self.assertEqual(files, [])


if __name__ == '__main__': unittest.main()
