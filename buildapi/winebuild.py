"""Product build of one system for a project version (TASKTYPE=winebuild):
WINE@Etersoft, RX@Etersoft, CRYPTO@Etersoft.

The robot (robot/funcs/winebuild) runs wine-etersoft-bootstrap-new.sh for the
task and writes <sales>/winebuild/<taskid>.log and <taskid>.progress; this
module enqueues such tasks and reads their stages and log.
"""
import os
from pathlib import Path
import re

import taskreader as tr

# Project versions with their distro.list: <product>/<version>/distro.list
ETERSOFT_PUB = Path('/var/ftp/pub/Etersoft')
PRODUCTS = ('WINE@Etersoft', 'RX@Etersoft', 'CRYPTO@Etersoft')
DEFAULT_PRODUCT = 'WINE@Etersoft'
RE_VERSION = re.compile(r'^[A-Za-z0-9][A-Za-z0-9.-]*$')
RE_SYSTEM = re.compile(r'^[A-Za-z0-9][A-Za-z0-9_.+-]*(/[A-Za-z0-9_.+-]+)+$')
ACTIVE = ('queued', 'running', 'running_stale', 'interrupted')
LOG_TAIL = 64 * 1024
# korinf writes the log of the package being built to <LIVE_LOG>/<dist>/<package>.log
LIVE_LOG = Path('/srv/builder/Projects/korinf/log')


class WineBuildError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


def systems(version, product=DEFAULT_PRODUCT):
    """Systems of a product version: the first field of its distro.list lines."""
    if product not in PRODUCTS:
        raise WineBuildError(400, f'unknown product (one of {", ".join(PRODUCTS)})')
    if not RE_VERSION.fullmatch(version or '') or version in ('.', '..'):
        raise WineBuildError(400, 'invalid version (e.g. 11-testing, 1.10, unstable)')
    path = ETERSOFT_PUB / product / version / 'distro.list'
    try:
        text = path.read_text(encoding='utf-8', errors='replace')
    except OSError:
        raise WineBuildError(404, f'no distro.list for {product} {version}')
    result = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        system = line.split()[0]
        if system not in result:
            result.append(system)
    return result


def is_winebuild(task):
    return task.fields.get('TASKTYPE') == 'winebuild'


def find_active(sales, version, dist, product=DEFAULT_PRODUCT):
    """A queued/running build task for the same product, version and system."""
    for task in tr.scan_sales(sales):
        if is_winebuild(task) and task.status in ACTIVE and \
                task.fields.get('COMPONENTNAME', DEFAULT_PRODUCT) == product and \
                task.fields.get('PROJECTVERSION') == version and task.fields.get('DIST') == dist:
            return task
    return None


def enqueue(version, dist, force, sales, taskid, product=DEFAULT_PRODUCT):
    """Write a system build task, or return the same active one: the robot builds
    tasks one by one, a second identical task would only build twice."""
    if dist not in systems(version, product):
        raise WineBuildError(400, f'{dist} is not in distro.list of {version}')
    if not RE_SYSTEM.fullmatch(dist):
        raise WineBuildError(400, 'invalid system')
    existing = find_active(sales, version, dist, product)
    if existing:
        return {'taskid': existing.taskid, 'new_path': existing.path, 'existing': True}
    lines = ['TASKTYPE=winebuild', f'COMPONENTNAME="{product}"',
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
        raise WineBuildError(500, f'cannot write task: {e}')
    return {'taskid': taskid, 'new_path': path, 'existing': False}


def _paths(sales, taskid):
    if not tr.RE_FILENAME.match(taskid + '.task'):
        raise WineBuildError(400, 'bad taskid')
    base = os.path.join(sales, 'winebuild', taskid)
    return base + '.progress', base + '.log'


def progress(sales, taskid):
    """Stages of a winebuild task from its progress file, None if it has not started:
    {'started', 'finished', 'rc', 'current', 'stages': [{'package', 'dist', 'phase', 'started',
     'finished', 'duration', 'result', 'steps': [{'at', 'status', 'text'}]}]}; phase: 'init' (only
    the build requirements, --init), 'build' or None (an old progress file)"""
    path, _ = _paths(sales, taskid)
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
                     'started': at, 'finished': None,
                     'duration': None, 'result': None, 'steps': []}
            result['stages'].append(stage)
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
    return result


def log_tail(sales, taskid, limit=LOG_TAIL):
    """The end of a winebuild task log, None if there is no log."""
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
    # wine32-* of an i586 companion log as wine-*
    names = [stage['package'], stage['package'].replace('wine32-', 'wine-', 1)]
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
