"""Progress polling, engine selection, and fixed-runner regression checks."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'buildapi'))
import main
import repair
import repair_engines as engines
from fastapi.testclient import TestClient

TASKID = '20260909120000.ABCD-1234.abcdefghij'


class ProgressTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.run = 'a' * 32
        self.work = self.root / TASKID / self.run
        self.work.mkdir(parents=True)
        self.state = dict(taskid=TASKID, run=self.run, status='review', engine='codex',
                          message='Готово', report='Отчёт', patch='', applied=[])
        repair.write_json(self.work.parent / 'status.json', self.state)
        self.client = TestClient(main.app)

    def tearDown(self):
        self.temp.cleanup()

    def test_live_output_grows_and_remains_after_finish(self):
        self.state['status'] = 'running'
        repair.write_json(self.work.parent / 'status.json', self.state)
        repair.write_json(self.root / 'active.json', self.state)
        handle = repair.lock(self.root)
        try:
            (self.work / 'worker.log').write_text('Подготовка\n')
            log = self.work / 'codex.log'
            log.write_text('exec\nbash -n recipe.sh\n')
            first = repair.progress(TASKID, self.root)
            self.assertEqual(first['status'], 'running')
            self.assertIn('bash -n', first['log'])
            with log.open('a') as out:
                out.write('Проверка завершена\n')
            self.assertIn('Проверка завершена', repair.progress(TASKID, self.root)['log'])
        finally:
            handle.close()
        self.state['status'] = 'review'
        repair.write_json(self.work.parent / 'status.json', self.state)
        self.assertIn('Проверка завершена', repair.progress(TASKID, self.root)['log'])

    def test_log_is_bounded_and_paths_are_not_user_controlled(self):
        log = self.work / 'codex.log'
        log.write_text('x' * 300000 + '\nEND\n')
        result = repair.progress(TASKID, self.root)
        self.assertLess(len(result['log']), 132000)
        self.assertIn('END', result['log'])
        self.assertIsNone(repair.progress('../config', self.root))
        log.unlink()
        log.symlink_to('/etc/passwd')
        with self.assertRaises(repair.RepairError):
            repair.progress(TASKID, self.root)
        self.state['run'] = '../other'
        repair.write_json(self.work.parent / 'status.json', self.state)
        with self.assertRaises(repair.RepairError):
            repair.progress(TASKID, self.root)

    def test_mimo_events_and_result(self):
        result = dict(outcome='repaired', confidence='high', summary='Исправлено', checks=['bash -n'])
        log = self.work / 'mimo.jsonl'
        entries = [dict(type='step_start'),
                   dict(type='tool_use', part=dict(tool='bash', state=dict(
                       input={'command': 'bash -n recipe.sh'}, output='OK'))),
                   dict(type='text', part={'text': json.dumps(result)})]
        log.write_text('\n'.join(map(json.dumps, entries)))
        self.state['engine'] = 'mimo'
        repair.write_json(self.work.parent / 'status.json', self.state)
        progress = repair.progress(TASKID, self.root)
        self.assertEqual(progress['engine_label'], 'MiMo (xmimo)')
        self.assertIn('bash -n recipe.sh', progress['log'])
        self.assertEqual(engines.mimo_result(log), result)
        log.write_text(json.dumps(dict(type='text', part={'text': 'Недостаточно данных'})))
        self.assertEqual(engines.mimo_result(log)['outcome'], 'needs_review')

    def test_api_and_form_select_engine(self):
        with patch.dict(main.CFG, {'API_KEY': 'test'}), patch.object(main, '_start_repair', return_value=self.state) as start:
            for engine in ('mimo', 'codex'):
                response = self.client.post(f'/api/task/{TASKID}/repair',
                    headers={'X-API-Key': 'test'}, json={'engine': engine})
                self.assertEqual(response.status_code, 202)
                self.assertEqual(start.call_args.args, (TASKID, engine))
                response = self.client.post(f'/task/{TASKID}/repair', data={'engine': engine}, follow_redirects=False)
                self.assertEqual(response.status_code, 303)
                self.assertEqual(start.call_args.args, (TASKID, engine))
            self.client.post(f'/api/task/{TASKID}/repair', headers={'X-API-Key': 'test'})
            self.assertEqual(start.call_args.args, (TASKID, 'mimo'))
        with self.assertRaises(ValueError):
            engines.executable('sh -c evil')

    def test_progress_routes_auth_and_no_cache(self):
        with patch.dict(main.CFG, {'API_KEY': 'test'}), \
                patch.object(repair, 'progress', return_value={**self.state, 'log': '<script>not html</script>'}):
            self.assertEqual(self.client.get(f'/api/task/{TASKID}/repair/log').status_code, 401)
            for url, headers in [(f'/task/{TASKID}/repair/log', {}),
                                 (f'/api/task/{TASKID}/repair/log', {'X-API-Key': 'test'})]:
                response = self.client.get(url, headers=headers)
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.headers['cache-control'], 'no-store')
                self.assertEqual(response.json()['log'], '<script>not html</script>')

    def test_mimo_keeps_host_read_only(self):
        checkout = self.work / 'checkout'
        checkout.mkdir()
        with patch.object(engines, 'selected_mimo_model', return_value='xiaomi/mimo-v2.5'):
            command = engines.mimo_command('/usr/bin/xmimo', checkout, self.work)
        self.assertIn('--ro-bind', command)
        self.assertIn('--unshare-pid', command)
        self.assertNotIn('--yolo', command)
        binds = [command[i+1:i+3] for i, arg in enumerate(command) if arg == '--bind']
        self.assertEqual(binds, [[str(checkout)] * 2, [str(self.work / 'mimo-runtime')] * 2])
        self.assertEqual(command[-9:], ['/usr/bin/xmimo', 'run', '--pure', '--format', 'json', '--dir', str(checkout), '--model', 'xiaomi/mimo-v2.5'])

    def test_uses_recent_mimo_model(self):
        state = self.root / 'mimo/state'
        state.mkdir(parents=True)
        (state / 'model.json').write_text(json.dumps({'recent': [
            {'providerID': 'xiaomi', 'modelID': 'mimo-v2.5'}]}))
        with patch.dict(engines.os.environ, {'MIMOCODE_HOME': str(state.parent)}):
            self.assertEqual(engines.selected_mimo_model(), 'xiaomi/mimo-v2.5')


if __name__ == '__main__':
    unittest.main()
