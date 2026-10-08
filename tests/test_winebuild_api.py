"""winebuild API on temporary queue and FTP directories: nothing real is enqueued."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'buildapi'))
import buildlogs
import main
import taskreader as tr
import winebuild
from fastapi.testclient import TestClient

PROGRESS = """\
start\t1000
stage\t1000\teepm\tx86_64/ALTLinux/p10
step\t1001\tSKIP\teepm is up-to-date
result\t1001\teepm\tskipped
stage\t1001\twine-etersoft\tx86_64/ALTLinux/p10\tbuild
step\t1600\tDONE\tbuild in hasher p10 (599 s)
result\t1700\twine-etersoft\tok
stage\t1700\twine32-etersoft\ti586/ALTLinux/p10
"""


class WineBuildApi(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.sales = root / 'sales'
        self.sales.mkdir()
        self.done = root / 'done'
        self.done.mkdir()
        pub = root / 'pub'
        wine = pub / 'WINE@Etersoft' / '11-testing'
        wine.mkdir(parents=True)
        (wine / 'distro.list').write_text(
            'x86_64/ALTLinux/p10\tAlt p10\n#x86_64/Fedora/35\told\n\nXimperLinux/Deferred\tXimper\n')
        for product, version in (('RX@Etersoft', '1.10'), ('RX@Etersoft', 'unstable'), ('CRYPTO@Etersoft', '0.5-9')):
            (pub / product / version).mkdir(parents=True)
            (pub / product / version / 'distro.list').write_text('x86_64/ALTLinux/p10\tAlt p10\n')
        self.patches = [patch.object(main, 'SALES', str(self.sales)),
                        patch.object(main, 'DONE', str(self.done)),
                        patch.dict(main.CFG, {'API_KEY': 'test-secret'}),
                        patch.object(winebuild, 'ETERSOFT_PUB', pub),
                        patch.object(buildlogs, 'PUB', root / 'ftp' / 'pub'),
                        patch.object(buildlogs, 'PVT', root / 'ftp' / 'pvt'),
                        patch.object(buildlogs, 'LIVE', root / 'live')]
        self.root = root
        for p in self.patches:
            p.start()
        self.client = TestClient(main.app)
        self.headers = {'X-API-Key': 'test-secret'}

    def tearDown(self):
        for p in reversed(self.patches):
            p.stop()
        self.temp.cleanup()

    def build(self, **body):
        body = {'version': '11-testing', 'dist': 'x86_64/ALTLinux/p10', **body}
        return self.client.post('/api/wine/build', headers=self.headers, json=body)

    def test_enqueue(self):
        r = self.build()
        self.assertEqual(r.status_code, 200, r.text)
        data = r.json()
        self.assertFalse(data['existing'])
        fields, _, _ = tr.parse_file(self.sales / (data['taskid'] + '.task'))
        self.assertEqual(fields['TASKTYPE'], 'winebuild')
        self.assertEqual(fields['PROJECTVERSION'], '11-testing')
        self.assertEqual(fields['DIST'], 'x86_64/ALTLinux/p10')
        self.assertEqual(fields['CLEAR_FAILED_ON_RESTART'], '1')
        self.assertNotIn('FORCE', fields)
        task = self.client.get('/api/task/' + data['taskid'], headers=self.headers).json()
        self.assertEqual((task['product'], task['version'], task['status']), ('WINE@Etersoft', '11-testing', 'queued'))

    def test_force(self):
        data = self.build(force=True).json()
        fields, _, _ = tr.parse_file(self.sales / (data['taskid'] + '.task'))
        self.assertEqual(fields['FORCE'], '1')

    def test_same_active_task_is_returned(self):
        first = self.build().json()
        second = self.build(force=True).json()
        self.assertEqual((second['taskid'], second['existing']), (first['taskid'], True))
        self.assertEqual(len(list(self.sales.glob('*.task'))), 1)
        other = self.build(dist='XimperLinux/Deferred').json()
        self.assertNotEqual(other['taskid'], first['taskid'])

    def test_finished_task_is_not_reused(self):
        first = self.build().json()
        path = self.sales / (first['taskid'] + '.task')
        path.rename(str(path) + '.failed')
        second = self.build().json()
        self.assertFalse(second['existing'])
        self.assertNotEqual(second['taskid'], first['taskid'])

    def test_validation(self):
        self.assertEqual(self.build(dist='x86_64/Fedora/35').status_code, 400)
        self.assertEqual(self.build(dist='all').status_code, 400)
        self.assertEqual(self.build(version='12-testing').status_code, 404)
        self.assertEqual(self.build(version='../11-testing').status_code, 400)
        self.assertEqual(list(self.sales.glob('*.task')), [])

    def test_api_key_required(self):
        r = self.client.post('/api/wine/build', json={'version': '11-testing', 'dist': 'x86_64/ALTLinux/p10'})
        self.assertEqual(r.status_code, 401)
        self.assertEqual(list(self.sales.glob('*.task')), [])

    def test_systems(self):
        r = self.client.get('/api/wine/systems?version=11-testing', headers=self.headers)
        self.assertEqual(r.json(), ['x86_64/ALTLinux/p10', 'XimperLinux/Deferred'])

    def test_progress_and_log(self):
        taskid = self.build().json()['taskid']
        self.assertEqual(self.client.get(f'/api/task/{taskid}/progress', headers=self.headers).status_code, 404)
        (self.sales / 'winebuild').mkdir()
        (self.sales / 'winebuild' / (taskid + '.progress')).write_text(PROGRESS)
        (self.sales / 'winebuild' / (taskid + '.log')).write_text('line 1\n\x1b[1mline 2\x1b[0m\n')
        p = self.client.get(f'/api/task/{taskid}/progress', headers=self.headers).json()
        self.assertEqual((p['started'], p['finished'], p['current']), (1000, None, 'wine32-etersoft'))
        self.assertEqual([(s['package'], s['result'], s['duration']) for s in p['stages']],
                         [('eepm', 'skipped', 1), ('wine-etersoft', 'ok', 699), ('wine32-etersoft', None, None)])
        self.assertEqual(p['stages'][1]['steps'], [{'at': 1600, 'status': 'DONE', 'text': 'build in hasher p10 (599 s)'}])
        # the phase of a stage (--init); an old progress file has none
        self.assertEqual([s['phase'] for s in p['stages'][:2]], [None, 'build'])
        log = self.client.get(f'/api/task/{taskid}/log?tail=11', headers=self.headers)
        self.assertEqual(log.text, '[…]\nline 2\n')
        self.assertEqual(self.client.get(f'/task/{taskid}/log').text, 'line 1\nline 2\n')
        page = self.client.get(f'/task/{taskid}').text
        self.assertIn('Этапы сборки', page)
        self.assertIn('wine32-etersoft', page)

    def test_finished_progress(self):
        taskid = self.build().json()['taskid']
        (self.sales / 'winebuild').mkdir()
        (self.sales / 'winebuild' / (taskid + '.progress')).write_text(
            PROGRESS + 'result\t1800\twine32-etersoft\tfailed\nend\t1800\t0\n')
        p = self.client.get(f'/api/task/{taskid}/progress', headers=self.headers).json()
        self.assertEqual((p['finished'], p['rc'], p['current']), (1800, 0, None))
        self.assertEqual(p['stages'][-1]['result'], 'failed')

    def test_component_logs_include_i586_companion(self):
        taskid = self.build().json()['taskid']
        wine = self.root / 'ftp' / 'pub' / 'Etersoft' / 'WINE@Etersoft' / '11-testing' / 'WINE'
        for dist, name in (('x86_64/ALTLinux/p10', 'wine-etersoft'), ('ALTLinux/p10', 'wine32-etersoft'),
                           ('ALTLinux/p11', 'wine32-etersoft')):
            (wine / dist / 'log').mkdir(parents=True)
            (wine / dist / 'log' / (name + '.log')).write_text('log')
        (wine / 'ALTLinux/p10/log/wine32-etersoft.build.failed').touch()
        logs = self.client.get(f'/api/task/{taskid}/logs', headers=self.headers).json()
        self.assertEqual([(r['component'], r['target'], r['failed']) for r in logs],
                         [('wine32-etersoft', 'WINE/ALTLinux/p10', True),
                          ('wine-etersoft', 'WINE/x86_64/ALTLinux/p10', False)])

    def product_build(self, **body):
        body = {'product': 'RX@Etersoft', 'version': '1.10', 'dist': 'x86_64/ALTLinux/p10', **body}
        return self.client.post('/api/product/build', headers=self.headers, json=body)

    def test_product_build(self):
        for product, version in (('RX@Etersoft', '1.10'), ('RX@Etersoft', 'unstable'), ('CRYPTO@Etersoft', '0.5-9')):
            with self.subTest(product=product, version=version):
                r = self.product_build(product=product, version=version)
                self.assertEqual(r.status_code, 200, r.text)
                fields, _, _ = tr.parse_file(self.sales / (r.json()['taskid'] + '.task'))
                self.assertEqual((fields['COMPONENTNAME'], fields['PROJECTVERSION']), (product, version))
                task = self.client.get('/api/task/' + r.json()['taskid'], headers=self.headers).json()
                self.assertEqual(task['product'], product)

    def test_products_have_their_own_tasks(self):
        rx = self.product_build().json()
        self.assertTrue(self.product_build().json()['existing'])
        wine = self.build().json()
        self.assertFalse(wine['existing'])
        self.assertNotEqual(wine['taskid'], rx['taskid'])

    def test_product_validation(self):
        self.assertEqual(self.product_build(product='SELTA@Etersoft').status_code, 400)
        self.assertEqual(self.product_build(version='1.9').status_code, 404)
        self.assertEqual(self.product_build(version='..').status_code, 400)
        r = self.client.get('/api/product/systems?product=RX@Etersoft&version=1.10', headers=self.headers)
        self.assertEqual(r.json(), ['x86_64/ALTLinux/p10'])

    def test_live_log(self):
        taskid = self.build().json()['taskid']
        url = f'/api/task/{taskid}/live-log'
        self.assertEqual(self.client.get(url, headers=self.headers).status_code, 404)
        (self.sales / 'winebuild').mkdir()
        progress = self.sales / 'winebuild' / (taskid + '.progress')
        live = self.root / 'live'
        with patch.object(winebuild, 'LIVE_LOG', live):
            # x86_64 stage
            progress.write_text('start\t1000\nstage\t1000\twine-etersoft\tx86_64/ALTLinux/p10\n')
            (live / 'x86_64/ALTLinux/p10').mkdir(parents=True)
            (live / 'x86_64/ALTLinux/p10/wine-etersoft.log').write_text('compiling dlls\n')
            r = self.client.get(url, headers=self.headers).json()
            self.assertEqual((r['package'], r['dist'], r['log']), ('wine-etersoft', 'x86_64/ALTLinux/p10', 'compiling dlls\n'))
            # the i586 companion: wine32-etersoft logs as wine-etersoft in ALTLinux/p10
            progress.write_text('start\t1000\nstage\t1000\twine32-etersoft\ti586/ALTLinux/p10\n')
            (live / 'ALTLinux/p10').mkdir(parents=True)
            (live / 'ALTLinux/p10/wine-etersoft.log').write_text('i586 build\n')
            self.assertEqual(self.client.get(url, headers=self.headers).json()['log'], 'i586 build\n')
            # another log name: the newest log of the stage
            progress.write_text('start\t1000\nstage\t1000\tkdriveclient\tx86_64/ALTLinux/p10\n')
            (live / 'x86_64/ALTLinux/p10/rxkdriveclient.log').write_text('kdrive\n')
            self.assertEqual(self.client.get(url, headers=self.headers).json()['log'], 'kdrive\n')
            # the stage is over: nothing is live
            progress.write_text(progress.read_text() + 'result\t1100\tkdriveclient\tok\n')
            self.assertEqual(self.client.get(url, headers=self.headers).status_code, 404)

    def test_bad_taskid(self):
        self.assertEqual(self.client.get('/api/task/..%2Fx/progress', headers=self.headers).status_code, 404)
        self.assertEqual(self.client.get('/api/task/bad/log', headers=self.headers).status_code, 400)


if __name__ == '__main__':
    unittest.main()
