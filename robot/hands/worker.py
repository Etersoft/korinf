#!/usr/bin/env python3
"""Bounded robot task scheduler. One scheduler owns a queue, including its children."""
import fcntl
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'buildapi'))
import products  # noqa: E402

# the products of robot/products.list: their tasks are known to the scheduler
PRODUCTS = products.names()


def fields(task):
    result = {}
    for line in task.read_text(errors='replace').splitlines():
        match = re.match(r'^\s*([A-Z_]+)=(.*)$', line)
        if match:
            key, value = match.groups()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in '\"\'':
                value = value[1:-1]
            result.setdefault(key, value)
    return result


def build_only(task):
    data = fields(task)
    return bool(data.get('TASKTYPE') == 'winebuild' or data.get('PACKAGE'))


def personal(data):
    return (not data.get('TASKTYPE') and not data.get('PACKAGE') and
            any(product in data.get('COMPONENTNAME', '')
                for product in PRODUCTS))


def resource(task):
    """Unknown and list tasks run exclusively; known products lock system aliases.

    Both architectures and all products share a system lock: bootstrap dependencies
    and package logs can be shared even when their module images differ.
    """
    data = fields(task)
    if data.get('TASKTYPE') != 'winebuild' and not personal(data):
        return None
    if not personal(data) and data.get('COMPONENTNAME', 'WINE@Etersoft') not in PRODUCTS:
        return None
    dist = data.get('DIST', '')
    if personal(data) and not dist:
        return 'license-only'
    if not re.fullmatch(r'[A-Za-z0-9@_.+-]+/[A-Za-z0-9_.+-]+', re.sub(r'^(x86_64|i586)/', '', dist)):
        return None
    # Union aliases after removing architecture, also covering the 32-bit bootstrap.
    aliases = {}
    def base(value):
        return re.sub(r'^(x86_64|i586)/', '', value)
    def root(value):
        while value in aliases:
            value = aliases[value]
        return value
    for filename in ('linked', 'linked-x86_64-wine'):
        for line in (ROOT / 'etc' / filename).read_text().splitlines():
            parts = line.split()
            if len(parts) == 2 and not line.lstrip().startswith('#'):
                left, right = (root(base(p)) for p in parts)
                if left != right:
                    aliases[left] = right
    return root(base(dist))


def alive(marker):
    try:
        pid = int(marker.read_text().strip())
        return pid > 0 and Path('/proc', str(pid)).exists()
    except (OSError, ValueError):
        return False


def recover(sales):
    for task in sales.glob('*.task.interrupted'):
        target = task.with_suffix('')
        if time.time() - task.stat().st_mtime > 3600 and not target.exists():
            task.rename(target)
    for marker in sales.glob('*.task.run'):
        if alive(marker):
            # An old shell worker may still own the queue during an upgrade.
            return False
    for marker in sales.glob('*.task.run'):
        task = marker.with_suffix('')
        if task.exists():
            task.rename(Path(str(task) + '.interrupted'))
        marker.unlink(missing_ok=True)
    return True


def run(sales, debug=False):
    if not (sales / 'SALESDIR').is_file():
        raise ValueError('Missing SALESDIR in ' + str(sales))
    jobs = int(os.environ.get('KORINF_TASK_JOBS', '2'))
    if jobs < 1:
        raise ValueError('KORINF_TASK_JOBS must be positive')
    queue_id = hashlib.sha256(os.fsencode(sales)).hexdigest()[:16]
    state = Path(os.environ.get('KORINF_WORKER_STATE', str(sales.parent / '.korinf-worker'))) / queue_id
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (state / 'scheduler.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        if not recover(sales):
            print('Queue still owned by an earlier worker', flush=True)
            return
        pending = sorted(sales.glob('*.task'), reverse=True)
        seen = set(pending)
        active = {}
        fast_tried = set()
        timeout = os.environ.get('KORINF_TASK_TIMEOUT', '6h')
        command = os.environ.get('KORINF_BUILDTASK', str(ROOT / 'robot/hands/buildtask.sh'))
        work_root = Path(os.environ.get('KORINF_WORK_ROOT', '/srv/arobot/tasks'))
        print('Observe {}: up to {} parallel tasks'.format(sales, jobs), flush=True)
        try:
            while pending or active:
                for task, (proc, key, log, fast) in list(active.items()):
                    rc = proc.poll()
                    if rc is None:
                        continue
                    log.close()
                    if fast and task.exists():
                        pending.append(task)
                    elif rc in (124, 137) and task.exists():
                        with task.open('a') as out:
                            out.write('\n# build FAILED at {} (Error: timeout {})\n'.format(time.ctime(), timeout))
                        task.rename(Path(str(task) + '.failed'))
                    Path(str(task) + '.run').unlink(missing_ok=True)
                    del active[task]
                    print('Finished {}: exit {}'.format(task.name, rc), flush=True)
                if not (sales / 'STOP').exists():
                    new = sorted(set(sales.glob('*.task')) - seen)
                    pending.extend(new)
                    pending.sort(reverse=True)
                    seen.update(new)
                if (sales / 'STOP').exists():
                    pending.clear()  # Drain running tasks without interrupting builds.
                pending = [task for task in pending if task.exists()]
                pending.sort(key=lambda task: (not build_only(task), task.name), reverse=True)
                for task in pending[:]:
                    if build_only(task) and any(not build_only(other) for other in pending):
                        continue
                    if not task.exists():
                        pending.remove(task)
                        continue
                    fast = task not in fast_tried and personal(fields(task))
                    if fast:
                        if any(entry[3] for entry in active.values()):
                            continue
                    elif sum(not entry[3] for entry in active.values()) >= jobs:
                        continue
                    key = resource(task)
                    occupied = [entry[1] for entry in active.values()]
                    if active and (key is None or None in occupied or key in occupied):
                        continue
                    logpath = state / (task.name + '.log')
                    log = logpath.open('ab')
                    env = dict(os.environ, KORINF_TASK_WORKDIR=str(work_root / queue_id / task.stem))
                    defer = state / (task.name + '.defer')
                    defer.unlink(missing_ok=True)
                    env['KORINF_DEFER_FILE'] = str(defer)
                    env['KORINF_READY_ONLY'] = '1' if fast else ''
                    env['KORINF_NO_BUILD'] = ''
                    env['KORINF_CHECK_ONLY'] = ''
                    limit = os.environ.get('KORINF_READY_TIMEOUT', '5m') if fast else timeout
                    # Inherit the queue lock: after scheduler death a new scheduler
                    # cannot overlap surviving builds, including timeout's children.
                    proc = subprocess.Popen(['timeout', '--kill-after=30s', limit, command,
                                             '--debug' if debug else '--real', str(task)],
                                            stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, env=env,
                                            pass_fds=(lock.fileno(),), start_new_session=True)
                    active[task] = (proc, key, log, fast)
                    if fast:
                        fast_tried.add(task)
                    marker = Path(str(task) + '.run')
                    temporary = Path(str(marker) + '.tmp')
                    temporary.write_text(str(proc.pid) + '\n')
                    temporary.replace(marker)
                    pending.remove(task)
                    print('Started {}: pid {}, system {}, lane {}, log {}'.format(task.name, proc.pid, key or 'exclusive', 'ready' if fast else 'build', logpath), flush=True)
                if active:
                    time.sleep(0.2)
        finally:
            # Do not abandon builds on an ordinary Python exception/interrupt.
            for proc, _, log, _ in active.values():
                proc.wait()
                log.close()


if __name__ == '__main__':
    try:
        run(Path(sys.argv[1]).resolve(), len(sys.argv) > 2 and sys.argv[2] == 'debug')
    except (IndexError, ValueError, OSError) as error:
        sys.exit(str(error))
