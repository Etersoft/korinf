"""System build of a product version: one system of its distro.list
(the products are in robot/products.list).

The robot (robot/funcs/winebuild) runs the product's bootstrap script for the
task and writes <sales>/winebuild/<taskid>.log and <taskid>.progress; this
module enqueues such tasks and reads their stages and log. The task type is
TASKTYPE=winebuild for every product (the name stays for the queued tasks).
"""
import os
import fcntl
from pathlib import Path
import re

import products
import taskreader as tr

# Project versions with their distro.list: <product>/<version>/distro.list
ETERSOFT_PUB = Path('/var/ftp/pub/Etersoft')
TASKTYPE = 'winebuild'
# the product of a task written before the tasks named it (COMPONENTNAME)
LEGACY_PRODUCT = 'WINE@Etersoft'
RE_VERSION = re.compile(r'^[A-Za-z0-9][A-Za-z0-9.-]*$')
RE_SYSTEM = re.compile(r'^[A-Za-z0-9][A-Za-z0-9_.+-]*(/[A-Za-z0-9_.+-]+)+$')
ACTIVE = ('queued', 'running', 'running_stale', 'interrupted')
LOG_TAIL = 64 * 1024
# korinf writes the log of the package being built to <LIVE_LOG>/<dist>/<package>.log
LIVE_LOG = Path('/srv/builder/Projects/korinf/log')


class BuildError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


def check_product(product):
    if not products.get(product):
        raise BuildError(400, f'unknown product (one of {", ".join(products.names())})')
    return product


def systems(version, product):
    """Systems of a product version: the first field of its distro.list lines."""
    check_product(product)
    if not RE_VERSION.fullmatch(version or '') or version in ('.', '..'):
        raise BuildError(400, 'invalid version (e.g. 11-testing, 1.10, unstable)')
    path = ETERSOFT_PUB / product / version / 'distro.list'
    try:
        text = path.read_text(encoding='utf-8', errors='replace')
    except OSError:
        raise BuildError(404, f'no distro.list for {product} {version}')
    result = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        system = line.split()[0]
        if system not in result:
            result.append(system)
    return result


def is_system_build(task):
    return task.fields.get('TASKTYPE') == TASKTYPE


def find_active(sales, version, dist, product, *, force=False):
    """A queued/running build task for the same product, version and system."""
    for task in tr.scan_sales(sales):
        if (is_system_build(task) and task.status in ACTIVE and
                (not force or task.fields.get('FORCE') == '1') and
                task.fields.get('COMPONENTNAME', LEGACY_PRODUCT) == product and
                (ETERSOFT_PUB / product / task.fields.get('PROJECTVERSION', '')).resolve() ==
                (ETERSOFT_PUB / product / version).resolve() and
                task.fields.get('DIST', '').removeprefix('i586/') == dist.removeprefix('i586/')):
            return task
    return None


def enqueue(version, dist, force, sales, taskid, product, *, sisyphus_companion=False):
    """Serialize duplicate detection and atomic publication across API and cron."""
    with open(os.path.join(sales, '.systembuild-enqueue.lock'), 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return _enqueue(version, dist, force, sales, taskid, product, sisyphus_companion)


def _enqueue(version, dist, force, sales, taskid, product, sisyphus_companion=False):
    """Write a system build task, or return the same active one: the robot builds
    tasks one by one, a second identical task would only build twice."""
    available = systems(version, product)
    companion = (sisyphus_companion and dist == 'ALTLinux/Sisyphus'
                 and 'x86_64/ALTLinux/Sisyphus' in available)
    if dist not in available and not companion:
        raise BuildError(400, f'{dist} is not in distro.list of {version}')
    if not RE_SYSTEM.fullmatch(dist):
        raise BuildError(400, 'invalid system')
    existing = find_active(sales, version, dist, product, force=force)
    if existing:
        return {'taskid': existing.taskid, 'new_path': existing.path, 'existing': True}
    lines = [f'TASKTYPE={TASKTYPE}', f'COMPONENTNAME="{product}"',
             f'PROJECTVERSION="{version}"', f'DIST="{dist}"', 'CLEAR_FAILED_ON_RESTART=1']
    if force:
        lines.append('FORCE=1')
    path = os.path.join(sales, taskid + '.task')
    tmp = path + '.tmp'
    try:
        with open(tmp, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
        os.replace(tmp, path)
    except OSError as e:
        try:
            os.remove(tmp)
        except OSError:
            pass
        raise BuildError(500, f'cannot write task: {e}')
    return {'taskid': taskid, 'new_path': path, 'existing': False}


def _paths(sales, taskid):
    if not tr.RE_FILENAME.match(taskid + '.task'):
        raise BuildError(400, 'bad taskid')
    base = os.path.join(sales, 'winebuild', taskid)
    return base + '.progress', base + '.log'


def progress(sales, taskid):
    """Stages of a system build task from its progress file, None if it has not started:
    {'started', 'finished', 'rc', 'current', 'stages': [{'package', 'dist', 'phase', 'started',
     'finished', 'duration', 'result', 'steps': [{'at', 'status', 'text'}]}]}; phase: 'init' (only
    the build requirements, --init), 'build' or None (an old progress file); 'source': the src.rpm of
    the stage, 'version': its version-release, 'command': the korinf command of the stage (both from
    the task log for an old progress file)"""
    path, log = _paths(sales, taskid)
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            lines = f.read().splitlines()
    except OSError:
        return None
    result = {'started': None, 'finished': None, 'rc': None, 'current': None, 'stages': []}
    stage = None
    for line in lines:
        parts = line.split('\t')
        kind = parts[0]
        try:
            at = int(parts[1])
        except (IndexError, ValueError):
            continue
        if kind == 'start':
            result['started'] = at
        elif kind == 'stage' and len(parts) >= 4:
            stage = {'package': parts[2], 'dist': parts[3], 'phase': parts[4] if len(parts) > 4 else None,
                     'started': at, 'finished': None, 'source': None, 'version': None, 'command': None,
                     'duration': None, 'result': None, 'steps': []}
            result['stages'].append(stage)
        elif kind == 'command' and stage is not None and len(parts) >= 3:
            stage['command'] = '\t'.join(parts[2:])
        elif kind == 'source' and stage is not None and len(parts) >= 3:
            stage['source'] = parts[2]
        elif kind == 'step' and stage is not None and len(parts) >= 4:
            stage['steps'].append({'at': at, 'status': parts[2], 'text': '\t'.join(parts[3:])})
        elif kind == 'result' and stage is not None and len(parts) >= 4:
            stage['result'] = parts[3]
            stage['finished'] = at
            stage['duration'] = at - stage['started']
        elif kind == 'end':
            result['finished'] = at
            result['rc'] = int(parts[2]) if len(parts) > 2 and parts[2].lstrip('-').isdigit() else None
    if result['finished'] is None and result['stages'] and result['stages'][-1]['result'] is None:
        result['current'] = result['stages'][-1]['package']
    if result['stages'] and not any(s['source'] or s['command'] for s in result['stages']):
        _sources_from_log(log, result['stages'])
    for s in result['stages']:
        if s['source']:
            name = s['source'].removesuffix('.src.rpm')
            s['version'] = name.removeprefix(s['package'] + '-')
    return result


RE_LOG_STAGE = re.compile(r'^> \./[^ ]+\.sh [^ ]+')
RE_LOG_SOURCE = re.compile(r'^Build .*/([^/ ]+\.src\.rpm) package$')


def _sources_from_log(log, stages):
    """The korinf command and the src.rpm of each stage from the task log, for a progress file
    written before the robot recorded them: the stages of the log and of the progress file come
    in the same order."""
    try:
        with open(log, encoding='utf-8', errors='replace') as f:
            index = -1
            for line in f:
                if RE_LOG_STAGE.match(line):
                    index += 1
                    if index < len(stages):
                        stages[index]['command'] = line[2:].rstrip('\n')
                elif 0 <= index < len(stages) and (m := RE_LOG_SOURCE.match(line.rstrip('\n'))):
                    stages[index]['source'] = m.group(1)
    except OSError:
        pass


def log_tail(sales, taskid, limit=LOG_TAIL):
    """The end of a system build task log, None if there is no log."""
    _, path = _paths(sales, taskid)
    try:
        with open(path, 'rb') as f:
            f.seek(0, 2)
            size = f.tell()
            f.seek(max(0, size - limit))
            data = f.read(limit)
    except OSError:
        return None
    text = data.decode('utf-8', errors='replace')
    text = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', text)
    return ('[…]\n' if size > limit else '') + text


def live_log(sales, taskid, limit=LOG_TAIL):
    """The live korinf log of the package a running system build builds now:
    {'package', 'dist', 'path', 'mtime', 'log'}, None if no stage is running."""
    current = progress(sales, taskid)
    if not current or current['finished'] or not current['stages'] or current['stages'][-1]['result']:
        return None
    stage = current['stages'][-1]
    dist = stage['dist'].removeprefix('i586/')
    if not RE_SYSTEM.fullmatch(dist) and not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.+-]*/[A-Za-z0-9_.+-]+', dist):
        return None
    directory = LIVE_LOG / dist
    # a package logged under another name (wine32-etersoft of an i586 companion as wine-etersoft)
    names = [stage['package']] + [stage['package'].replace(a, b, 1) for a, b in
                                  (p['log_alias'] for p in products.PRODUCTS.values() if p['log_alias'])
                                  if stage['package'].startswith(a)]
    path = next((directory / (n + '.log') for n in names if (directory / (n + '.log')).is_file()), None)
    if path is None:
        # another name (kdriveclient builds rxkdriveclient): the newest log of the stage
        try:
            fresh = [p for p in directory.glob('*.log') if p.stat().st_mtime >= stage['started']]
        except OSError:
            fresh = []
        path = max(fresh, key=lambda p: p.stat().st_mtime) if fresh else None
    if path is None or not path.resolve().is_relative_to(LIVE_LOG.resolve()):
        return {'package': stage['package'], 'dist': stage['dist'], 'path': None, 'mtime': None, 'log': ''}
    with open(path, 'rb') as f:
        f.seek(0, 2)
        size = f.tell()
        f.seek(max(0, size - limit))
        text = f.read(limit).decode('utf-8', errors='replace')
    text = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', text)
    return {'package': stage['package'], 'dist': stage['dist'], 'path': str(path), 'mtime': path.stat().st_mtime,
            'log': ('[…]\n' if size > limit else '') + text}
