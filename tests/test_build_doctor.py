"""Regression tests for compact diagnostics and the legacy sales-tasks entry point."""
import json
import lzma
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'buildapi'))
import doctor
import taskreader as tr


class DoctorTests(unittest.TestCase):
    def task(self, error, dist='x86_64/RedOS/7.3'):
        return tr.Task('20261013102649.ABCD-1234.abcdefghij', 'failed', '',
                       fields=dict(DIST=dist, PROJECTVERSION='10-testing', COMPONENTNAME='WINE@Etersoft'),
                       failures=[('Вт 13 окт 2026 13:35:57 MSK', error)], product='WINE@Etersoft')

    def test_components_latest_attempt_and_deduplication(self):
        task = self.task('build WINE@Etersoft 10-testing x86_64/RedOS/7.3: failed wine-etersoft, wine32-etersoft, wine32-etersoft, exit 0')
        task.failures.insert(0, ('old', "Can't rebuild old-component component"))
        self.assertEqual(doctor.components(task), ['wine-etersoft', 'wine32-etersoft'])
        self.assertEqual(doctor.components(self.task("Can't rebuild wine-etersoft component")), ['wine-etersoft'])
        self.assertEqual(doctor.components(self.task('Package wine32-etersoft should be rebuilt from /tmp/source.src.rpm')), ['wine32-etersoft'])

    def test_unknown_errors_are_counted(self):
        tasks = [self.task('unexpected failure'), self.task('unexpected failure')]
        result = doctor.triage(tasks)
        self.assertEqual(result['total_tasks'], 2)
        self.assertEqual(result['groups'][0]['component'], 'unknown')
        self.assertEqual(result['groups'][0]['count'], 2)

    def test_failure_dates_in_both_robot_locales(self):
        task = self.task('failure')
        ru = doctor.failure_time(task)
        task.failures = [('Tue Oct 13 13:35:57 MSK 2026', 'failure')]
        self.assertEqual(doctor.failure_time(task), ru)
        self.assertEqual(doctor.log_time_relation(ru - 86400, ru), 'older')
        self.assertEqual(doctor.log_time_relation(ru + 86400, ru), 'newer')
        self.assertEqual(doctor.log_time_relation(ru - 2, ru), 'near_attempt')
        task.failures = [('not a timestamp', 'failure')]
        task.mtime = ru
        self.assertIsNone(doctor.failure_time(task))

    def test_evidence_ignores_spec_and_cleanup_errors(self):
        text = '''STEP  * [10:00:00] convert ...
123 # configure: error: example from spec
[ DONE ]
STEP  * [10:01:00] test built packages requirements ...
No match for argument: libavcodec62
Error: Unable to find a match: libavcodec62
[FAILED]
STEP  * [10:02:00] umount ...
rm: Permission denied
[ DONE ]
'''
        result = doctor.evidence(text)
        self.assertIn('test built packages requirements', result['stage'])
        self.assertTrue(result['cause_found'])
        self.assertIn('libavcodec62', '\n'.join(result['excerpt']))
        self.assertNotIn('Permission denied', '\n'.join(result['excerpt']))
        self.assertNotIn('example from spec', '\n'.join(result['excerpt']))

    def test_unrecognized_error_keeps_context_without_claiming_cause(self):
        result = doctor.evidence('STEP  * [10:00:00] build ...\nstrange output\n[FAILED]\n')
        self.assertFalse(result['cause_found'])
        self.assertIn('strange output', result['excerpt'])

    def test_companion_architecture_is_not_confused_with_64_bit(self):
        task = self.task('Package wine32-etersoft-grdwine should be rebuilt')
        def discover(target):
            dist = target.fields['DIST']
            return [dict(component='wine-etersoft-grdwine', path='/logs/' + dist,
                         target='WINE/' + dist, filename='wine-etersoft-grdwine.log.xz')]
        with patch.object(doctor.buildlogs, 'discover', side_effect=discover):
            logs = doctor.discover_logs(task, doctor.components(task))
        self.assertEqual([row['target'] for row in logs], ['WINE/RedOS/7.3'])

    def test_plain_log_tail_is_bounded(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / 'build.log'
            path.write_text('x' * 10000 + '\nError: test\n')
            text, truncated = doctor.read_log(path, limit=100)
            self.assertTrue(truncated)
            self.assertLessEqual(len(text), 100)
            self.assertIn('Error: test', text)

    def test_compressed_log_uses_ercat_and_bounds_output(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            ercat = root / 'ercat'
            ercat.write_text('#!/usr/bin/env python3\nimport lzma,sys\nsys.stdout.buffer.write(lzma.open(sys.argv[1], "rb").read())\n')
            ercat.chmod(0o755)
            path = root / 'build.log.xz'
            path.write_bytes(lzma.compress(b'x' * 10000 + b'\nError: example\n'))
            with patch.dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH']):
                text, truncated = doctor.read_log(path, limit=100)
                self.assertIn('Error: example', text)
                self.assertTrue(truncated)
                self.assertLessEqual(len(text), 100)
                with self.assertRaisesRegex(RuntimeError, 'decompression limit'):
                    doctor.read_log(path, maximum=100)

    def test_ercat_warning_is_failure_even_with_zero_exit(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            script = root / 'ercat'
            script.write_text('#!/bin/sh\nprintf "Warning: Failed to unpack\\n" >&2\nexit 0\n')
            script.chmod(0o755)
            with patch.dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH']):
                with self.assertRaisesRegex(RuntimeError, 'ercat failed'):
                    doctor.read_log(root / 'broken.log.xz')

    def test_cli_and_legacy_stat_handle_system_build_tasks(self):
        with tempfile.TemporaryDirectory() as sales:
            root = Path(sales)
            for index, dist in enumerate(['x86_64/RedOS/7.3', 'x86_64/RedOS/8.0']):
                (root / f'2026101310264{index}.ABCD-1234.abcdefghij.task.failed').write_text(
                    f'DIST="{dist}"\nPROJECTVERSION="10-testing"\nCOMPONENTNAME="WINE@Etersoft"\n'
                    'TASKTYPE=winebuild\n# build FAILED at Tue Oct 13 13:35:57 MSK 2026 '
                    '(Error: build WINE@Etersoft: failed wine-etersoft, wine-etersoft, wine32-etersoft, exit 0)\n')
            env = dict(os.environ, SALES_DIR=sales, PYTHONDONTWRITEBYTECODE='1')
            command = [str(ROOT / 'tools/build-doctor'), 'triage', '--json']
            result = json.loads(subprocess.check_output(command, env=env))
            self.assertEqual(result['total_tasks'], 2)
            self.assertEqual(len(result['groups']), 4)
            self.assertTrue(all(row['count'] == 1 for row in result['groups']))
            stats = subprocess.check_output([str(ROOT / 'tools/sales-tasks'), 'stat'], env=env, text=True)
            self.assertIn('1  x86_64/RedOS/7.3\n', stats)
            self.assertIn('1  x86_64/RedOS/8.0\n', stats)
            self.assertIn('2  WINE@Etersoft\n', stats)
            errors = subprocess.check_output([str(ROOT / 'tools/sales-tasks'), 'errors'], env=env, text=True)
            self.assertIn('wine32-etersoft', errors)
            filtered = json.loads(subprocess.check_output(command + ['--version', 'other'], env=env))
            self.assertEqual(filtered['total_tasks'], 0)


if __name__ == '__main__':
    unittest.main()
