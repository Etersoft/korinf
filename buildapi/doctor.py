"""Read-only, compact diagnostics shared by the build-doctor CLI."""
import argparse
import copy
import datetime as dt
import json
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import sys
import tempfile
import time
from zoneinfo import ZoneInfo

import buildlogs
import taskreader as tr

PACKAGE = r'[A-Za-z0-9_][A-Za-z0-9_.+-]*'
ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')
CAUSE = re.compile(r'(?i)(^\s*(?:error:|fatal:|no match for argument:|E:|cpio:|configure: error:)|'
                   r'undefined reference|unpacking of .* failed|unmet dependencies|'
                   r'nothing provides|conflicts with file|cannot find|cannot open|'
                   r'permission denied|no such file or directory|unable to find a match)')


def components(task):
    """Use only the latest attempt, deduplicating repeated init/build failures."""
    error = (task.failures[-1][1] or '') if task.failures else ''
    names = re.findall(r'(?:Package |Can\x27t rebuild |for )(' + PACKAGE + r')'
                       r'(?= should be rebuilt| component|\s)', error)
    match = re.search(r': failed (.+?)(?:, exit\b|$)', error)
    if match:
        names += [name.strip() for name in match[1].split(',')
                  if re.fullmatch(PACKAGE, name.strip())]
    if not names and task.fields.get('PACKAGE'):
        names = [task.fields['PACKAGE']]
    return sorted(set(names)) or ['unknown']


def task_summary(task):
    return dict(taskid=task.taskid, status=task.status, product=task.product,
                dist=task.fields.get('DIST', ''), version=task.fields.get('PROJECTVERSION', ''),
                failure=task.failures[-1][1] if task.failures else None,
                failure_at=task.failures[-1][0] if task.failures else None)


def triage(tasks):
    from doctor_tasks import review_summary
    reviews = {task.taskid: review_summary(task) for task in tasks}
    groups = {}
    for task in tasks:
        for component in components(task):
            key = (task.product, task.fields.get('DIST', ''),
                   task.fields.get('PROJECTVERSION', ''), component)
            row = groups.setdefault(key, dict(zip(('product', 'dist', 'version', 'component'), key),
                                               count=0, taskids=[]))
            row['count'] += 1
            row['taskids'].append(task.taskid)
    rows = sorted(groups.values(), key=lambda row: (-row['count'], row['dist'], row['version'], row['component']))
    for row in rows:
        row['taskids'].sort()
        metadata = [reviews[taskid] for taskid in row['taskids']]
        row['review'] = dict(present=sum(item['state'] == 'present' for item in metadata),
                             missing=sum(item['state'] == 'missing' for item in metadata),
                             unreadable=sum(item['state'] == 'unreadable' for item in metadata),
                             before_latest_failure=sum(item['before_latest_failure'] is True for item in metadata),
                             latest_review_at=max((item['updated_at'] for item in metadata
                                                   if item['updated_at'] is not None), default=None))
    return dict(total_tasks=len(tasks), groups=rows, reviews=reviews)


def failure_time(task):
    """Parse robot's English/Russian date output without using the task mtime."""
    if not task.failures:
        return None
    raw = task.failures[-1][0]
    months = 'jan feb mar apr may jun jul aug sep oct nov dec'.split()
    russian = 'янв фев мар апр мая июн июл авг сен окт ноя дек'.split()
    text = raw.lower()
    for index, month in enumerate(russian):
        text = re.sub(r'\b' + month + r'\b', months[index], text)
    match = re.search(r'(\d{1,2}) ([a-z]{3}) (\d{4}) (\d\d:\d\d:\d\d) (msk|utc)', text)
    if match:
        day, month, year, clock, zone = match.groups()
    else:
        match = re.search(r'([a-z]{3})\s+(\d{1,2}) (\d\d:\d\d:\d\d) (msk|utc) (\d{4})', text)
        if not match:
            return None
        month, day, clock, zone, year = match.groups()
    try:
        hour, minute, second = map(int, clock.split(':'))
        return dt.datetime(int(year), months.index(month) + 1, int(day), hour, minute, second,
                           tzinfo=ZoneInfo('Europe/Moscow' if zone == 'msk' else 'UTC')).timestamp()
    except ValueError:
        return None


def log_time_relation(mtime, attempt):
    if attempt is None:
        return 'unknown'
    delta = mtime - attempt
    return 'older' if delta < -300 else 'newer' if delta > 300 else 'near_attempt'


def read_log(path, limit=256 * 1024, maximum=64 * 1024 * 1024, timeout=20):
    """Read compressed logs with ercat; bound time, decompressed bytes and memory."""
    path = Path(path)
    if path.suffix not in ('.xz', '.gz', '.bz2'):
        with path.open('rb') as stream:
            stream.seek(0, 2)
            size = stream.tell()
            stream.seek(max(0, size - limit))
            data = stream.read(limit)
        return data.decode('utf-8', errors='replace'), size > limit
    data = b''
    total = 0
    with tempfile.TemporaryFile() as errors:
        proc = subprocess.Popen(['ercat', str(path)], stdout=subprocess.PIPE,
                                stderr=errors, start_new_session=True)
        try:
            deadline = time.monotonic() + timeout
            with selectors.DefaultSelector() as selector:
                selector.register(proc.stdout, selectors.EVENT_READ)
                while True:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0 or not selector.select(remaining):
                        raise RuntimeError('ercat: timeout')
                    chunk = os.read(proc.stdout.fileno(), 65536)
                    if not chunk:
                        break
                    total += len(chunk)
                    if total > maximum:
                        raise RuntimeError('log exceeds decompression limit (64 MiB)')
                    data = (data + chunk)[-limit:]
            rc = proc.wait(timeout=max(0.1, deadline - time.monotonic()))
            errors.seek(0)
            stderr = errors.read(4096).decode('utf-8', errors='replace')
            # Some ercat versions return success even when decompression failed.
            if rc or 'Failed to unpack' in stderr:
                raise RuntimeError('ercat failed: ' + stderr.strip())
        finally:
            if proc.poll() is None:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait()
            proc.stdout.close()
    return data.decode('utf-8', errors='replace'), total > limit


def evidence(text, lines=10):
    """Prefer the failing STEP, avoiding errors quoted in specs or successful steps."""
    text = ANSI.sub('', text)
    blocks = re.split(r'(?m)^(?=STEP\s+\*)', text)
    failed = [block for block in blocks if re.search(r'\[\s*FAILED\s*\]', block)]
    block = failed[-1] if failed else blocks[-1]
    content = block.splitlines()
    stage = next((line.strip() for line in content if line.startswith('STEP')), None)
    if stage is None:
        stages = [line.strip() for line in content
                  if re.match(r'\s*\* \[\d\d:\d\d:\d\d\]', line) and '[FAILED]' in line]
        stage = stages[-1] if stages else None
    hits = [i for i, line in enumerate(content) if CAUSE.search(line) and not line.lstrip().startswith(('+', '#'))]
    indexes = set()
    for index in hits:
        indexes.update(range(max(0, index - 1), min(len(content), index + 2)))
    selected = [content[i] for i in sorted(indexes)] if hits else [line for line in content if line.strip()][-lines:]
    excerpt = [line[:500] for line in selected[-lines:]]
    return dict(stage=stage, cause_found=bool(hits), excerpt=excerpt)


def discover_logs(task, names):
    target = copy.copy(task)
    target.fields = dict(task.fields)
    if not target.fields.get('COMPONENTNAME') and target.fields.get('PRODUCT', '').startswith('WINE@Etersoft'):
        target.fields['COMPONENTNAME'] = 'WINE@Etersoft'
    records = buildlogs.discover(target)
    # License tasks can depend on a 32-bit companion too, not only system builds.
    if any(name.startswith('wine32-') for name in names) and target.fields.get('DIST', '').startswith('x86_64/'):
        target.fields['DIST'] = target.fields['DIST'].removeprefix('x86_64/')
        records += buildlogs.discover(target)
    result = {}
    for row in records:
        if 'unknown' not in names:
            matches = [name for name in names if name.replace('wine32-', 'wine-', 1) == row['component']]
            if not matches:
                continue
            is64 = 'x86_64/' in row['target']
            if all(name.startswith('wine32-') for name in matches) and is64:
                continue
            if not any(name.startswith('wine32-') for name in matches) and task.fields.get('DIST', '').startswith('x86_64/') and not is64:
                continue
        if '.config.log' in row['filename']:
            continue
        result[row['path']] = row
    return list(result.values())


def diagnose(task, sales, component=None, limit=3, verbose=False):
    names = [component] if component else components(task)
    records = discover_logs(task, names)
    total_records = len(records)
    if not verbose:
        # Old installation logs add noise when a newer build log exists.
        primary = {}
        for row in records:
            if '.install.log' not in row['filename']:
                key = (row['component'], row['target'])
                primary[key] = max(primary.get(key, 0), row['mtime'])
        records = [row for row in records if '.install.log' not in row['filename']
                   or row['mtime'] >= primary.get((row['component'], row['target']), 0)]
    # Prefer one primary build log per component and architecture before install logs.
    records.sort(key=lambda r: ('.install.log' in r['filename'], not r['failed'], -r['mtime']))
    tasklog = Path(sales) / 'winebuild' / (task.taskid + '.log')
    if tasklog.is_file():
        total_records += 1
        records.insert(0, dict(path=str(tasklog), mtime=tasklog.stat().st_mtime,
                               component='system-build', filename=tasklog.name))
    attempt = failure_time(task)
    logs = []
    for record in records[:limit]:
        row = {key: record[key] for key in ('path', 'mtime', 'component')}
        row['time_relation'] = log_time_relation(row['mtime'], attempt)
        try:
            text, truncated = read_log(row['path'])
            row.update(evidence(text, lines=30 if verbose else 10), truncated=truncated)
        except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
            row['read_error'] = str(exc)
        logs.append(row)
    return dict(task=task_summary(task), components=names, attempt_at=attempt,
                logs=logs, omitted_logs=max(0, total_records - len(logs)),
                next_command=f'tools/build-doctor diagnose {task.taskid} --verbose --limit 10')


def main(argv=None):
    parser = argparse.ArgumentParser(description='Compact build diagnostics and explicit operator reviews (no rebuild or queue changes).')
    sub = parser.add_subparsers(dest='command', required=True)
    import doctor_tasks
    doctor_tasks.register(sub)
    for name in ('triage', 'diagnose', 'deps'):
        command = sub.add_parser(name)
        command.add_argument('--sales-dir', default=os.environ.get('SALES_DIR', str(Path.home() / 'sales')))
        command.add_argument('--json', action='store_true')
        command.add_argument('--verbose', action='store_true')
        if name == 'triage':
            command.add_argument('--dist', default='')
            command.add_argument('--version', default='')
            command.add_argument('--product', default='')
        else:
            command.add_argument('taskid')
            command.add_argument('--component')
            command.add_argument('--limit', type=int, choices=range(1, 21), default=3, metavar='1..20')
            if name == 'deps':
                command.add_argument('--query', action='store_true', help='Search package candidates through korexec')
                command.add_argument('--module', help='Explicit KORINFMODULE for --query')
    args = parser.parse_args(argv)
    if args.command in ('status', 'review'):
        return doctor_tasks.run(args, parser)
    if not Path(args.sales_dir).is_dir():
        parser.error('sales directory does not exist: ' + args.sales_dir)
    tasks = tr.scan_sales(args.sales_dir)
    if args.command == 'triage':
        tasks = [task for task in tasks if task.status == 'failed'
                 and args.dist in task.fields.get('DIST', '')
                 and (not args.version or args.version == task.fields.get('PROJECTVERSION'))
                 and args.product in ' '.join((task.product, task.fields.get('PRODUCT', '')))]
        result = triage(tasks)
    else:
        taskid = args.taskid.removesuffix('.task.failed')
        task = next((task for task in tasks if task.taskid == taskid), None)
        if task is None:
            parser.error('task not found in sales: ' + args.taskid)
        if args.command == 'deps':
            import doctor_deps
            try:
                result = doctor_deps.report(task, args.component, args.query, args.module)
            except (ValueError, OSError, RuntimeError, subprocess.SubprocessError) as exc:
                parser.error(str(exc))
        else:
            result = diagnose(task, args.sales_dir, args.component, args.limit, args.verbose)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    elif args.command == 'deps':
        doctor_deps.print_report(result, args.verbose)
    elif args.command == 'triage':
        print(f"Failed tasks: {result['total_tasks']} (one task can have several failed components)")
        print(f"{'N':>3}  {'DIST':<30} {'VERSION':<15} COMPONENT")
        for row in result['groups']:
            print(f"{row['count']:3}  {row['dist']:<30} {row['version']:<15} {row['component']}")
            ids = row['taskids'] if args.verbose else row['taskids'][:1]
            print('     ' + ', '.join(ids) + (f" (+{row['count'] - 1})" if not args.verbose and row['count'] > 1 else ''))
            review = row['review']
            stamp = (dt.datetime.fromtimestamp(review['latest_review_at']).astimezone().isoformat(timespec='seconds')
                     if review['latest_review_at'] is not None else 'unknown')
            print(f"     Reviews: {review['present']}/{row['count']}; missing={review['missing']}; "
                  f"unreadable={review['unreadable']}; before failure={review['before_latest_failure']}; latest={stamp}")
    else:
        task = result['task']
        print(f"{task['taskid']}: {task['status']} | {task['dist']} | {task['version']}")
        print(f"Failure at: {task['failure_at'] or 'unknown'}\n{task['failure'] or 'No failure recorded'}")
        for log in result['logs']:
            stamp = dt.datetime.fromtimestamp(log['mtime']).astimezone().isoformat(timespec='seconds')
            print(f"\n{log['path']}\nLog at: {stamp}; relation to attempt: {log['time_relation']}")
            if log['time_relation'] != 'near_attempt':
                print('WARNING: this log is not confirmed to belong to the failed attempt.')
            if 'read_error' in log:
                print('Read error: ' + log['read_error'])
                continue
            print(log['stage'] or 'Failing STEP not identified')
            if not log['cause_found']:
                print('Cause not identified; showing context only.')
            print('\n'.join(log['excerpt']))
        if not result['logs']:
            print('No matching logs found; cause remains unknown.')
        if result['omitted_logs']:
            print(f"\nOther logs: {result['omitted_logs']}")
        print('\nMore: ' + result['next_command'])
    return 0


if __name__ == '__main__':
    sys.exit(main())
