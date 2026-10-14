"""Queue/archive status and explicit operator review for build-doctor."""
import datetime as dt
import json
import os
from pathlib import Path
import re

import comments
import taskreader as tr


def register(sub):
    for name in ('status', 'review'):
        parser = sub.add_parser(name, help='Queue/archive status' if name == 'status' else 'Record an operator review')
        parser.add_argument('taskids', nargs='*')
        parser.add_argument('--sales-dir', default=os.environ.get('SALES_DIR', str(Path.home() / 'sales')))
        parser.add_argument('--dist')
        parser.add_argument('--version')
        parser.add_argument('--product')
        parser.add_argument('--json', action='store_true')
        if name == 'status':
            parser.add_argument('--done-dir', default=os.environ.get('DONE_DIR', str(Path.home() / 'done')))
        else:
            parser.add_argument('--text-file', required=True)
            parser.add_argument('--log', required=True, help='The exact log actually examined')
            parser.add_argument('--dry-run', action='store_true')
            parser.add_argument('--replace', action='store_true', help='Allow replacing an existing review')


def normalize_ids(values):
    result = []
    for value in values:
        taskid, _ = tr.split_base_ext(value)
        if not re.fullmatch(r'\d{14}\.[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}\.[A-Za-z0-9]{10}', taskid):
            raise ValueError('Invalid task ID: ' + value)
        if taskid not in result:
            result.append(taskid)
    return result


def matches(task, dist=None, version=None, product=None):
    # Exact filters make mutation scope visible and reproducible.
    return ((dist is None or task.fields.get('DIST') == dist)
            and (version is None or task.fields.get('PROJECTVERSION') == version)
            and (product is None or task.product == product))


def select(args):
    ids = normalize_ids(args.taskids)
    filters = any((args.dist, args.version, args.product))
    if ids and filters:
        raise ValueError('Use task IDs or filters, not both')
    if not ids and not filters:
        raise ValueError('Supply task IDs or at least one filter')
    if not Path(args.sales_dir).is_dir():
        raise ValueError('Sales directory does not exist: ' + args.sales_dir)
    if args.command == 'review' and not ids and not (args.dist and args.version):
        raise ValueError('Review filters require exact --dist and --version')
    if ids:
        # For reviews, do not search an unrelated completion archive.
        done = args.done_dir if args.command == 'status' else str(Path(args.sales_dir) / '.no-done-archive')
        tasks = [tr.find_task(taskid, args.sales_dir, done) for taskid in ids]
        unknown = [taskid for taskid, task in zip(ids, tasks) if task is None]
        if unknown:
            raise ValueError('Tasks not found: ' + ', '.join(unknown))
        return tasks
    tasks = {task.taskid: task for task in tr.scan_sales(args.sales_dir)}
    if args.command == 'status':
        # Queue state wins if an old completion and a restarted task coexist.
        for task in tr.scan_done(args.done_dir, hours=48):
            tasks.setdefault(task.taskid, task)
    return sorted((task for task in tasks.values() if matches(task, args.dist, args.version, args.product)
                   and (args.command != 'review' or task.status == 'failed')), key=lambda task: task.taskid)


def review_summary(task):
    """Read metadata only; comment age alone never marks a review obsolete."""
    from doctor import failure_time
    result = dict(state='missing', updated_at=None, log_at=None, before_latest_failure=None)
    try:
        record = comments.read(task.taskid)
        if record is None:
            return result
        if not isinstance(record, dict) or not isinstance(record.get('text'), str) or not record['text'].strip():
            raise ValueError('Invalid review')
        for key in ('updated_at', 'log_at'):
            value = record.get(key)
            if value is not None:
                if isinstance(value, bool) or not isinstance(value, (int, float)):
                    raise ValueError('Invalid timestamp')
                dt.datetime.fromtimestamp(value)  # Reject NaN, infinity and out-of-range dates.
                result[key] = value
        result['state'] = 'present'
        attempt = failure_time(task) if task.status == 'failed' else None
        if attempt is not None and result['updated_at'] is not None:
            result['before_latest_failure'] = result['updated_at'] < attempt
    except (OSError, ValueError, TypeError, OverflowError):
        result = dict(state='unreadable', updated_at=None, log_at=None, before_latest_failure=None)
    return result


def review_label(review):
    if review['state'] != 'present':
        return review['state']
    stamp = (dt.datetime.fromtimestamp(review['updated_at']).astimezone().isoformat(timespec='seconds')
             if review['updated_at'] is not None else 'date unknown')
    return stamp + ('; before latest failure' if review['before_latest_failure'] else '')


def summary(task):
    failure = task.failures[-1][1] if task.failures else None
    if failure:
        for field in ('MAILTO', 'FULLNAME', 'OWNER', 'WEB_ORDER_USER'):
            value = task.fields.get(field)
            if value:
                failure = failure.replace(value, '[redacted]')
        failure = re.sub(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b', '[redacted]', failure)
    return dict(taskid=task.taskid, status=task.status, dist=task.fields.get('DIST', ''),
                version=task.fields.get('PROJECTVERSION', ''), product=task.product,
                last_failure=failure, failure_at=task.failures[-1][0] if task.failures else None,
                done_at=task.done_at, review=review_summary(task))


def reviewed_log(task, path, sales):
    import doctor
    # discover_logs keeps product/version/target restrictions and handles wine32.
    known = {Path(row['path']).resolve() for row in doctor.discover_logs(task, doctor.components(task) + ['unknown'])}
    systemlog = Path(sales) / 'winebuild' / (task.taskid + '.log')
    if systemlog.is_file():
        known.add(systemlog.resolve())
    if path not in known:
        raise ValueError(f'Log does not belong to the discovered product/target logs for {task.taskid}: {path}')
    return doctor.log_time_relation(path.stat().st_mtime, doctor.failure_time(task))


def review(tasks, sales, text_file, log, replace=False, dry_run=False):
    text = Path(text_file).read_text(encoding='utf-8').strip()
    if not text:
        raise ValueError('Review text is empty; comments are never deleted by this command')
    if len(re.split(r'\n\s*\n', text)) < 2:
        raise ValueError('Write the problem and solution as separate paragraphs')
    path = Path(log).resolve(strict=True)
    if not path.is_file():
        raise ValueError('Log must be a regular file')
    if not tasks:
        raise ValueError('No current failed tasks matched')
    stamp = path.stat().st_mtime
    prepared = []
    # Validate the whole batch, including conflicts, before any write.
    for task in tasks:
        if task.status != 'failed' or not Path(task.path).is_file():
            raise ValueError('Task is not currently failed: ' + task.taskid)
        previous = comments.read(task.taskid)
        if previous and not replace:
            raise ValueError('Review already exists; use --replace: ' + task.taskid)
        relation = reviewed_log(task, path, sales)
        prepared.append(dict(taskid=task.taskid, status=task.status, log=str(path), log_at=stamp,
                             time_relation=relation, action='replace' if previous else 'create'))
    # Re-read the selected queue entries immediately before writing. A robot may
    # have moved a task while discovery traversed the artifact tree.
    current = {task.taskid: task for task in tr.scan_sales(sales)}
    for task in tasks:
        now = current.get(task.taskid)
        if not now or now.status != 'failed' or now.fields != task.fields or now.failures != task.failures:
            raise ValueError('Task changed during review; retry: ' + task.taskid)
        if not replace and comments.read(task.taskid):
            raise ValueError('Review appeared during validation; retry with --replace: ' + task.taskid)
    if path.stat().st_mtime != stamp:
        raise ValueError('Log changed during validation; examine the new log before reviewing')
    if not dry_run:
        for row in prepared:
            saved = comments.write(row['taskid'], text, log_at=stamp)
            row['updated_at'] = saved['updated_at']
    return dict(dry_run=dry_run, count=len(prepared), reviews=prepared)


def run(args, parser):
    try:
        tasks = select(args)
        if args.command == 'status':
            result = dict(count=len(tasks), tasks=[summary(task) for task in tasks],
                          archive_hours=None if args.taskids else 48)
        else:
            result = review(tasks, args.sales_dir, args.text_file, args.log, args.replace, args.dry_run)
    except (OSError, ValueError, RuntimeError) as exc:
        parser.error(str(exc))
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    elif args.command == 'status':
        print(f"Tasks: {result['count']}" + ('; archive window: 48h' if result['archive_hours'] else ''))
        for row in result['tasks']:
            print(f"{row['taskid']}: {row['status']} | {row['dist']} | {row['version']}")
            if row['status'] == 'failed':
                print('  Review: ' + review_label(row['review']))
            if row['done_at']:
                print('  Done: ' + row['done_at'])
            if row['last_failure']:
                print(f"  Last failure ({row['failure_at']}): {row['last_failure']}")
    else:
        print(('Dry run: ' if args.dry_run else 'Recorded: ') + str(result['count']) + ' reviews')
        for row in result['reviews']:
            stamp = dt.datetime.fromtimestamp(row['log_at']).astimezone().isoformat(timespec='seconds')
            print(f"{row['taskid']}: {row['action']} | {stamp} | {row['time_relation']}")
        print('Log: ' + str(Path(args.log).resolve()))
    return 0
