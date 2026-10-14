import argparse
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'buildapi'))
import comments
import doctor_tasks as operations
import taskreader as tr

ID1 = '20261013102649.ABCD-1234.abcdefghij'
ID2 = '20261013102650.ABCD-1234.abcdefghik'


class TaskOperationsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.sales = self.root / 'sales'
        self.done = self.root / 'done'
        self.sales.mkdir()
        self.done.mkdir()
        self.commentpatch = patch.object(comments, 'ROOT', self.root / 'comments')
        self.commentpatch.start()
        self.addCleanup(self.commentpatch.stop)
        self.text = self.root / 'review.txt'
        self.text.write_text('Проблема: отсутствует зависимость.\n\nСпособ решения: правило исправлено.')
        self.log = self.root / 'build.log'
        self.log.write_text('failed build')
        os.utime(self.log, (1000, 1000))

    def task(self, taskid=ID1, status='failed', dist='x86_64/RedOS/7.3'):
        directory = self.done if status == 'done' else self.sales
        suffix = '.done' if status == 'done' else '.task.failed' if status == 'failed' else '.task'
        path = directory / (taskid + suffix)
        path.write_text(f'DIST="{dist}"\nPROJECTVERSION="10-testing"\nCOMPONENTNAME="WINE@Etersoft"\n'
                        'FULLNAME="Private Name"\nMAILTO="private@example.com"\n'
                        '# build FAILED at unknown (Error: failed for Private Name private@example.com)\n'
                        + ('# task done at yesterday\n' if status == 'done' else ''))
        return tr.find_task(taskid, str(self.sales), str(self.done))

    def args(self, command='status', ids=(), **filters):
        return argparse.Namespace(command=command, taskids=list(ids), sales_dir=str(self.sales),
                                  done_dir=str(self.done), dist=filters.get('dist'),
                                  version=filters.get('version'), product=filters.get('product'))

    def review(self, tasks, **options):
        with patch('doctor.discover_logs', return_value=[dict(path=str(self.log))]):
            return operations.review(tasks, str(self.sales), self.text, options.pop('log', self.log), **options)

    def test_explicit_ids_find_old_completion_filtered_scan_is_recent(self):
        self.task(status='done')
        path = self.done / (ID1 + '.done')
        os.utime(path, (1, 1))
        selected = operations.select(self.args(ids=[ID1]))
        self.assertEqual(selected[0].status, 'done')
        self.assertEqual(operations.select(self.args(dist='x86_64/RedOS/7.3')), [])

    def test_filters_exact_and_queue_wins_over_archive(self):
        self.task(status='done')
        self.task(status='queued')
        self.task(ID2, dist='x86_64/RedOS/7.30')
        selected = operations.select(self.args(dist='x86_64/RedOS/7.3'))
        self.assertEqual([(t.taskid, t.status) for t in selected], [(ID1, 'queued')])

    def test_summary_contains_no_personal_fields_or_values(self):
        result = operations.summary(self.task())
        encoded = json.dumps(result)
        for private in ('Private Name', 'private@example.com', 'FULLNAME', 'MAILTO'):
            self.assertNotIn(private, encoded)
        self.assertIn('last_failure', result)
        task = self.task()
        path = '/var/ftp/pub/Etersoft/WINE@Etersoft/10.10/sources/wine.src.rpm'
        task.failures = [('unknown', 'Cannot build ' + path)]
        self.assertIn(path, operations.summary(task)['last_failure'])

    def test_review_dry_run_then_write_real_log_metadata(self):
        task = self.task()
        alias = self.root / 'log-alias'
        alias.symlink_to(self.log)
        result = self.review([task], log=alias, dry_run=True)
        self.assertEqual(result['reviews'][0]['log_at'], 1000)
        self.assertIsNone(comments.read(ID1))
        before = time.time()
        self.review([task], log=alias)
        saved = comments.read(ID1)
        self.assertEqual(saved['log_at'], 1000)
        self.assertGreaterEqual(saved['updated_at'], before)
        self.assertIn('Способ решения:', saved['text'])

    def test_batch_prevalidation_rejects_conflict_without_any_write(self):
        tasks = [self.task(), self.task(ID2)]
        comments.write(ID2, 'Existing operator review')
        with self.assertRaisesRegex(ValueError, '--replace'):
            self.review(tasks)
        self.assertIsNone(comments.read(ID1))
        self.assertEqual(comments.read(ID2)['text'], 'Existing operator review')
        self.review(tasks, replace=True)
        self.assertIsNotNone(comments.read(ID1))

    def test_rejects_nonfailed_unrelated_log_and_empty_text(self):
        task = self.task(status='queued')
        with self.assertRaisesRegex(ValueError, 'currently failed'):
            self.review([task])
        task = self.task()
        other = self.root / 'other.log'
        other.touch()
        with self.assertRaisesRegex(ValueError, 'does not belong'):
            self.review([task], log=other)
        self.text.write_text('  \n')
        with self.assertRaisesRegex(ValueError, 'empty'):
            self.review([task])
        self.assertIsNone(comments.read(ID1))

    def test_batch_rechecks_queue_before_any_write(self):
        tasks = [self.task(), self.task(ID2)]
        def discovery(task, names):
            if task.taskid == ID2:
                Path(task.path).unlink()
            return [dict(path=str(self.log))]
        with patch('doctor.discover_logs', side_effect=discovery):
            with self.assertRaisesRegex(ValueError, 'changed during review'):
                operations.review(tasks, str(self.sales), self.text, self.log)
        self.assertIsNone(comments.read(ID1))

    def test_review_metadata_missing_and_unknown_failure_time(self):
        task = self.task()
        result = operations.review_summary(task)
        self.assertEqual(result['state'], 'missing')
        self.assertIsNone(result['before_latest_failure'])
        comments.write(task.taskid, 'Private comment text', log_at=1000)
        result = operations.review_summary(task)
        self.assertEqual(result['state'], 'present')
        self.assertIsNone(result['before_latest_failure'])
        self.assertNotIn('Private comment text', json.dumps(result))

    def test_review_comparison_uses_failure_not_age_and_does_not_write(self):
        import doctor
        task = self.task()
        task.failures = [('Вт 13 окт 2026 13:35:57 MSK', 'failure')]
        attempt = doctor.failure_time(task)
        comments.write(task.taskid, 'review', log_at=1000)
        path = comments.ROOT / (task.taskid + '.json')
        for delta, expected in ((-1, True), (0, False), (1, False)):
            data = dict(text='review', updated_at=attempt + delta, log_at=1000)
            path.write_text(json.dumps(data))
            before = (path.read_bytes(), path.stat().st_mtime_ns)
            self.assertIs(operations.review_summary(task)['before_latest_failure'], expected)
            self.assertEqual((path.read_bytes(), path.stat().st_mtime_ns), before)
        task.status = 'done'
        self.assertIsNone(operations.review_summary(task)['before_latest_failure'])

    def test_unreadable_review_is_distinct_from_missing(self):
        task = self.task()
        comments.write(task.taskid, 'review')
        path = comments.ROOT / (task.taskid + '.json')
        for data in ('{bad json', '[]', '{"text":"secret", "updated_at":"bad"}',
                     '{"text":"secret", "updated_at":Infinity}'):
            path.write_text(data)
            result = operations.review_summary(task)
            self.assertEqual(result['state'], 'unreadable')
            self.assertNotIn('secret', json.dumps(result))

    def test_triage_reads_review_once_and_counts_all_components(self):
        import doctor
        first, second = self.task(), self.task(ID2)
        first.failures = [('unknown', 'build: failed wine-etersoft, wine32-etersoft, exit 0')]
        second.failures = [('unknown', "Can't rebuild wine-etersoft component")]
        comments.write(first.taskid, 'review')
        with patch.object(comments, 'read', wraps=comments.read) as read:
            result = doctor.triage([first, second])
        self.assertEqual(read.call_count, 2)
        group = next(row for row in result['groups'] if row['component'] == 'wine-etersoft')
        self.assertEqual(group['review']['present'], 1)
        self.assertEqual(group['review']['missing'], 1)
        self.assertEqual(group['review']['before_latest_failure'], 0)
        self.assertEqual(result['reviews'][second.taskid]['state'], 'missing')

    def test_mutation_filters_require_dist_and_version(self):
        self.task()
        with self.assertRaisesRegex(ValueError, '--dist and --version'):
            operations.select(self.args(command='review', dist='x86_64/RedOS/7.3'))
        with self.assertRaisesRegex(ValueError, 'Invalid task ID'):
            operations.select(self.args(ids=['../../escape']))
        selected = operations.select(self.args(command='review', dist='x86_64/RedOS/7.3', version='10-testing'))
        self.assertEqual([t.taskid for t in selected], [ID1])


if __name__ == '__main__':
    unittest.main()
