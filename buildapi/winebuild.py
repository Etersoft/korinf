"""WINE@Etersoft build of one system for a project version (TASKTYPE=winebuild).

The robot (robot/funcs/winebuild) runs wine-etersoft-bootstrap-new.sh for the
task and writes <sales>/winebuild/<taskid>.log and <taskid>.progress; this
module enqueues such tasks and reads their stages and log.
"""
import os
from pathlib import Path
import re

import taskreader as tr

# Project versions with their distro.list: WINE@Etersoft/<version>/distro.list
WINE_PUB = Path('/var/ftp/pub/Etersoft/WINE@Etersoft')
RE_VERSION = re.compile(r'^[0-9][A-Za-z0-9.-]*$')
RE_SYSTEM = re.compile(r'^[A-Za-z0-9][A-Za-z0-9_.+-]*(/[A-Za-z0-9_.+-]+)+$')
ACTIVE = ('queued', 'running', 'running_stale', 'interrupted')
LOG_TAIL = 64 * 1024


class WineBuildError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


def systems(version):
    """Systems of a project version: the first field of its distro.list lines."""
    if not RE_VERSION.fullmatch(version or ''):
        raise WineBuildError(400, 'invalid version (e.g. 11-testing)')
    path = WINE_PUB / version / 'distro.list'
    try:
        text = path.read_text(encoding='utf-8', errors='replace')
    except OSError:
        raise WineBuildError(404, f'no distro.list for WINE@Etersoft {version}')
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


def find_active(sales, version, dist):
    """A queued/running winebuild task for the same version and system."""
    for task in tr.scan_sales(sales):
        if is_winebuild(task) and task.status in ACTIVE and \
                task.fields.get('PROJECTVERSION') == version and task.fields.get('DIST') == dist:
            return task
    return None


def enqueue(version, dist, force, sales, taskid):
    """Write a winebuild task, or return the same active one: the robot builds
    tasks one by one, a second identical task would only build twice."""
    if dist not in systems(version):
        raise WineBuildError(400, f'{dist} is not in distro.list of {version}')
    if not RE_SYSTEM.fullmatch(dist):
        raise WineBuildError(400, 'invalid system')
    existing = find_active(sales, version, dist)
    if existing:
        return {'taskid': existing.taskid, 'new_path': existing.path, 'existing': True}
    lines = ['TASKTYPE=winebuild', 'COMPONENTNAME="WINE@Etersoft"',
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
    {'started', 'finished', 'rc', 'current', 'stages': [{'package', 'dist', 'started',
     'finished', 'duration', 'result', 'steps': [{'at', 'status', 'text'}]}]}"""
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
            stage = {'package': parts[2], 'dist': parts[3], 'started': at, 'finished': None,
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
