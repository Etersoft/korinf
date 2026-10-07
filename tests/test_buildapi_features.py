"""Isolated HTTP, repair and log tests; never enqueue a production build."""
import fcntl
import json
import lzma
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'buildapi'))
import buildlogs
import main
import repair
import repair_engines
import taskreader as tr
from fastapi.testclient import TestClient

TASKID = '20260909120000.ABCD-1234.abcdefghij'


class Features(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.sales = self.root / 'sales'
        self.sales.mkdir()
        self.done = self.root / 'done'
        self.done.mkdir()
        self.taskfile = self.sales / (TASKID + '.task.failed')
        self.taskfile.write_text('PACKAGE="eepm"\nDIST="x86_64/ALTLinux/Sisyphus"\n')
        self.task = tr.find_task(TASKID, str(self.sales), str(self.done))
        self.patches = [patch.object(main, 'SALES', str(self.sales)),
                        patch.object(main, 'DONE', str(self.done)),
                        patch.dict(main.CFG, {'API_KEY': 'test-secret'}),
                        patch.object(buildlogs, 'PUB', self.root / 'pub'),
                        patch.object(buildlogs, 'PVT', self.root / 'pvt'),
                        patch.object(buildlogs, 'LIVE', self.root / 'live')]
        for p in self.patches:
            p.start()
        self.client = TestClient(main.app)
        self.headers = {'X-API-Key': 'test-secret'}

    def tearDown(self):
        for p in reversed(self.patches):
            p.stop()
        self.temp.cleanup()

    def test_build_clears_previous_failure_by_default(self):
        for force in (None, False, True):
            with self.subTest(force=force):
                body = {'package': 'eepm', 'dist': 'x86_64/ALTLinux/Sisyphus'}
                if force is not None:
                    body['force'] = force
                response = self.client.post('/api/build', headers=self.headers, json=body)
                self.assertEqual(response.status_code, 200, response.text)
                fields = tr.parse_file(response.json()['new_path'])[0]
                self.assertEqual(fields['CLEAR_FAILED_ON_RESTART'], '1')
                self.assertEqual(fields['PACKAGE'], body['package'])
                self.assertEqual(fields['DIST'], body['dist'])
                if force:
                    self.assertEqual(fields['FORCE'], '1')
                else:
                    self.assertNotIn('FORCE', fields)

    def test_rebuild_auth_validation_and_task_fields(self):
        for endpoint in ('/api/rebuild', f'/api/task/{TASKID}/repair'):
            self.assertEqual(self.client.post(endpoint, json={'package': 'eepm'}).status_code, 401)
        base = self.root / 'repo/buildapi'
        (base.parent / 'etc/lists/x86_64').mkdir(parents=True)
        (base.parent / 'etc/lists/x86_64/build').write_text('x86_64/ALTLinux/Sisyphus\n')
        with patch.object(main, 'BASE_DIR', base):
            for arch, dist in [('all', 'all'), ('x86_64', 'x86_64/build')]:
                response = self.client.post('/api/rebuild', headers=self.headers,
                                            json={'package': 'eepm', 'arch': arch})
                self.assertEqual(response.status_code, 200, response.text)
                data = response.json()
                fields = tr.parse_file(data['new_path'])[0]
                self.assertEqual(fields['DIST'], dist)
                self.assertEqual(fields['PACKAGE'], 'eepm')
                self.assertEqual(fields['FORCE'], '1')
                self.assertEqual(fields['CLEAR_FAILED_ON_RESTART'], '1')
                self.assertIsNotNone(tr.find_task(data['taskid'], str(self.sales), str(self.done)))
            for body in ({'package': 'eepm', 'arch': '../x86_64'},
                         {'package': 'eepm', 'arch': 'unknown'},
                         {'package': 'eepm\nFORCE=1'}, {'package': '-oops'}):
                self.assertEqual(self.client.post('/api/rebuild', headers=self.headers, json=body).status_code, 400)

    def test_repair_routes_and_busy_error(self):
        with patch.object(repair, 'start', return_value={'status': 'starting'}) as start:
            response = self.client.post(f'/api/task/{TASKID}/repair', headers=self.headers)
            self.assertEqual(response.status_code, 202)
            self.assertEqual(start.call_args.args[0].taskid, TASKID)
            response = self.client.post(f'/task/{TASKID}/repair', headers={'Origin': 'http://evil.invalid'})
            self.assertEqual(response.status_code, 403)
        with patch.object(repair, 'start', side_effect=repair.RepairError(409, 'Занято')):
            response = self.client.post(f'/task/{TASKID}/repair')
            self.assertEqual(response.status_code, 409)
            self.assertIn('Занято', response.text)

    def test_repair_lock_and_stale_state(self):
        root = self.root / 'repairs'
        handle = repair.lock(root)
        with self.assertRaises(repair.RepairError):
            repair.start(self.task, self.root, root, engine="codex")
        handle.close()
        folder = root / TASKID
        folder.mkdir()
        repair.write_json(folder / 'status.json', dict(status='running', run='old'))
        self.assertEqual(repair.status(TASKID, root)['status'], 'interrupted')
        self.task.status = 'running'
        with self.assertRaises(repair.RepairError):
            repair.start(self.task, self.root, root, engine="codex")

    def test_logs_compression_path_safety_and_html(self):
        directory = buildlogs.PUB / 'Korinf/x86_64/ALTLinux/Sisyphus/log'
        directory.mkdir(parents=True)
        logfile = directory / 'eepm.log.xz'
        logfile.write_bytes(lzma.compress(b'building\n<script>alert(1)</script>\nFAILED\n'))
        (directory / 'eepm.build.failed').touch()
        (directory / 'other.log').write_text('unrelated')
        (directory / 'eepm.config.log').symlink_to('/etc/passwd')
        rows = buildlogs.discover(self.task)
        self.assertEqual(len(rows), 1)
        self.assertTrue(rows[0]['failed'])
        self.assertIn('FAILED', buildlogs.read_tail(logfile))
        response = self.client.get(f'/task/{TASKID}/logs/{rows[0]["id"]}')
        self.assertEqual(response.status_code, 200)
        self.assertIn('&lt;script&gt;', response.text)
        self.assertNotIn('<script>alert', response.text)
        self.assertEqual(self.client.get(f'/task/{TASKID}/logs/unknown').status_code, 404)
        page = self.client.get(f'/task/{TASKID}').text
        self.assertIn('Починить сборку', page)
        self.assertIn('Логи составляющих', page)
        self.assertIn('eepm.log.xz', page)
        self.assertIn('<meta name="color-scheme" content="light dark">', page)
        self.assertNotIn('/static/theme.js', page)


class ApplyRecipe(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        self.name = 'bin-common/eepm.sh'
        source = self.repo / self.name
        source.parent.mkdir()
        source.write_text('#!/bin/bash\necho old\n')
        repair.git(self.repo, 'init')
        repair.git(self.repo, 'add', '.')
        repair.git(self.repo, '-c', 'user.name=test', '-c', 'user.email=test@localhost', 'commit', '-m', 'input')
        self.checkout = self.root / 'checkout'
        repair.git(self.repo, 'clone', str(self.repo), str(self.checkout))
        self.baseline = {self.name: source.read_bytes()}
        (self.checkout / self.name).write_text('#!/bin/bash\necho fixed\n')
        self.task = self.root / 'sample.task.failed'
        self.task.write_bytes(b'PACKAGE=eepm\n')
        self.result = dict(outcome='repaired', confidence='high', checks=['bash -n'])

    def tearDown(self):
        self.temp.cleanup()

    def apply(self):
        return repair.apply_recipe(self.repo, self.checkout, self.baseline,
                                   self.task, b'PACKAGE=eepm\n', self.result, self.root)

    def test_applies_small_patch_and_keeps_backup(self):
        self.assertEqual(self.apply()[0], [self.name])
        self.assertIn('fixed', (self.repo / self.name).read_text())
        self.assertEqual((self.root / 'original-recipe.sh').read_bytes(), self.baseline[self.name])
        self.assertTrue(self.task.exists())

    def test_preserves_concurrent_edits(self):
        (self.repo / self.name).write_text('user edit\n')
        self.assertEqual(self.apply()[0], [])
        self.assertEqual((self.repo / self.name).read_text(), 'user edit\n')

    def test_rejects_unsafe_syntax_and_unrelated_files(self):
        (self.checkout / self.name).write_text('if then broken\n')
        with self.assertRaises(subprocess.CalledProcessError):
            self.apply()
        (self.checkout / self.name).write_text('#!/bin/bash\necho fixed\n')
        (self.checkout / 'unrelated.py').write_text('changed')
        self.assertEqual(self.apply()[0], [])

    def test_running_build_or_uncertain_result_is_not_applied(self):
        self.result['confidence'] = 'low'
        self.assertEqual(self.apply()[0], [])
        self.result['confidence'] = 'high'
        (self.root / 'other.task.run').touch()
        self.assertEqual(self.apply()[0], [])

    def _background_worker(self, engine):
        executable = self.root / 'codex'
        executable.write_text('''#!/usr/bin/env python3
import json, pathlib, sys
args = sys.argv
prompt = sys.stdin.read()
is_codex = '-C' in args
assert 'workspace-write' in args if is_codex else '--pure' in args
checkout = pathlib.Path(args[args.index('-C' if is_codex else '--dir') + 1])
(checkout / 'bin-common/eepm.sh').write_text('#!/bin/bash\\necho fixed\\n')
result = {
    'outcome': 'repaired', 'confidence': 'high', 'summary': 'Fixed test recipe',
    'checks': ['bash -n']
}
if is_codex:
    pathlib.Path(args[args.index('-o') + 1]).write_text(json.dumps(result))
else:
    print(json.dumps({'type':'text','part':{'text':json.dumps(result)}}), flush=True)
''')
        executable.chmod(0o755)
        self.task.rename(self.root / (TASKID + '.task.failed'))
        task = tr.Task(taskid=TASKID, status='failed', path=str(self.root / (TASKID + '.task.failed')),
                       fields={'PACKAGE': 'eepm'})
        state = self.root / 'state'
        with patch.object(repair_engines, 'executable', return_value=str(executable)), \
                patch.object(buildlogs, 'discover', return_value=[]):
            repair.start(task, self.repo, state, engine=engine)
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            result = repair.status(TASKID, state)
            if result['status'] not in repair.ACTIVE:
                break
            time.sleep(.05)
        self.assertEqual(result['status'], 'applied', result)
        self.assertEqual(result['applied'], [self.name])
        self.assertTrue(Path(task.path).exists())
        self.assertIn('echo fixed', (self.repo / self.name).read_text())

    def test_background_worker_end_to_end(self):
        self._background_worker('codex')

    @unittest.skipUnless(repair.shutil.which('bwrap'), 'requires bwrap')
    def test_mimo_background_worker_end_to_end(self):
        self._background_worker('mimo')


if __name__ == '__main__':
    unittest.main()
