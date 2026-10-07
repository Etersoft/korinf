"""Парсер .task/.done/.task.failed и сканер очереди korinf.

Статус задачи определяется по файловой системе (см. robot/hands/worker.sh):
  queued        <base>.task без <base>.task.run
  running       <base>.task + <base>.task.run (PID жив)
  running_stale <base>.task.run есть, но PID мёртв
  failed        <base>.task.failed
  broken        <base>.task.broken
  removed       <base>.task.removed
  interrupted   <base>.task.interrupted
  done          <base>.done   (в ~/done, локально)

Формат файла: shell-присваивания KEY=VALUE (3 стиля кавычек) +
опциональные маркеры '# build FAILED at ... (Error: ...)' и '# task done at ...'.
"""
import os
import re
import time
import datetime as dt
from dataclasses import dataclass, field

# --- Регексы ---
RE_FILENAME = re.compile(
    r'^(?P<ts>\d{14})\.(?P<regnum>[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4})\.'
    r'(?P<rand>[A-Za-z0-9]{10})\.(?P<ext>.+)$'
)
RE_KV = re.compile(r'^([A-Z_][A-Z0-9_]*)=(.*)$')
RE_FAILED = re.compile(r'^# build FAILED at (.+?) \(Error:\s*(.+)\)\s*$')
RE_FAILED_NOERR = re.compile(r'^# build FAILED at (.+?)\s*$')
RE_BROKEN = re.compile(r'^# task broken at (.+?) \(Error:\s*(.+)\)\s*$')
RE_DONE = re.compile(r'^# task done at (.+?)\s*$')
RE_PRODUCT_GROUP = re.compile(r'^([^@\s]+@Etersoft)')

# Роли расширений. Порядок важен: более длинные суффиксы (.task.run) — раньше.
EXT_ROLES = {
    '.task.run': 'run',
    '.task.failed': 'failed',
    '.task.broken': 'broken',
    '.task.removed': 'removed',
    '.task.interrupted': 'interrupted',
    '.task': 'task',
    '.done': 'done',
}

KNOWN_FIELDS = [
    'WEB_ORDER_USER', 'WEB_ORDER_ID', 'WEB_DOWNLOAD_REL',
    'PRODUCT', 'COMPONENTNAME', 'ETERREGNUM', 'DIST', 'DOWNLOADDIR',
    'PACKAGE', 'TASKTYPE', 'TARGETDIR', 'FORCE', 'CLEAR_FAILED_ON_RESTART',
    'MAILTO', 'FULLNAME', 'PROJECTVERSION', 'RELEASECANDIDAT',
    'TYPE_LICENSE', 'NAME_LICENSE', 'COUNT_LICENSE', 'OWNER',
    'DATE_START', 'DATE_END', 'SERVICE_END',
]


def _unquote(v: str) -> str:
    """Decode literal shell quoting without evaluating expansions or commands."""
    if len(v) >= 2 and v[0] == v[-1] == "'":
        return v[1:-1]
    if len(v) >= 2 and v[0] == v[-1] == '"':
        return re.sub(r'\\([$`"\\])', lambda m: m.group(1), v[1:-1])
    return v


def parse_text(text: str):
    """Разобрать содержимое файла задачи.

    Возвращает (fields, failures, done_at):
      fields   — dict известных полей (только присутствующие)
      failures — список (datestr, error|None), по одной на попытку
      done_at  — строка из последней '# task done at ...' или None
    """
    fields, failures, done_at = {}, [], None
    for raw in text.splitlines():
        line = raw.rstrip('\r')
        if not line:
            continue
        if line.startswith('#'):
            m = RE_FAILED.match(line)
            if m:
                failures.append((m.group(1), m.group(2)))
                continue
            m = RE_FAILED_NOERR.match(line)
            if m:
                failures.append((m.group(1), None))
                continue
            m = RE_BROKEN.match(line)
            if m:
                failures.append((m.group(1), m.group(2)))
                continue
            m = RE_DONE.match(line)
            if m:
                done_at = m.group(1)
            continue
        m = RE_KV.match(line)
        if m and m.group(1) in KNOWN_FIELDS:
            fields[m.group(1)] = _unquote(m.group(2))
    return fields, failures, done_at


def parse_file(path: str):
    """Прочитать файл (utf-8, ошибки → '?') и распарсить."""
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        return parse_text(f.read())


def product_group(componentname: str) -> str:
    """WINE@Etersoft Enterprise / Local → 'WINE@Etersoft'."""
    if not componentname:
        return '(unknown)'
    m = RE_PRODUCT_GROUP.match(componentname)
    return m.group(1) if m else componentname


def split_base_ext(filename: str):
    """'20241...euqe7.task.failed' -> ('20241...euqe7', 'failed')."""
    for suf, role in EXT_ROLES.items():
        if filename.endswith(suf):
            return filename[:-len(suf)], role
    return filename, None


def pid_alive(pid_str: str) -> bool:
    """Жив ли процесс (робот проверяет через /proc/<pid>)."""
    try:
        return os.path.isdir(f'/proc/{int(pid_str)}')
    except (ValueError, OSError):
        return False


def filename_timestamp(filename: str):
    """Время создания из первых 14 цифр имени (без依赖имости от mtime)."""
    m = RE_FILENAME.match(filename)
    if not m:
        return None
    try:
        return dt.datetime.strptime(m.group('ts'), '%Y%m%d%H%M%S').timestamp()
    except ValueError:
        return None


def derive_status(roles: dict) -> str:
    """Приоритет (важнее — выше), соответствует переходам в worker.sh/funcs/task."""
    if 'failed' in roles:
        return 'failed'
    if 'broken' in roles:
        return 'broken'
    if 'removed' in roles:
        return 'removed'
    if 'task' in roles:
        run = roles.get('run')
        if run and os.path.exists(run):
            try:
                pid = open(run).read().strip()
                if pid_alive(pid):
                    return 'running'
                return 'running_stale'
            except OSError:
                pass
        return 'queued'
    if 'interrupted' in roles:
        return 'interrupted'
    if 'done' in roles:
        return 'done'
    return 'unknown'


@dataclass
class Task:
    taskid: str
    status: str
    path: str
    fields: dict = field(default_factory=dict)
    failures: list = field(default_factory=list)
    done_at: str = None
    product: str = ''
    created_at: float = None
    mtime: float = 0.0


def _build_task(taskid: str, roles: dict, parse_content=True) -> Task:
    status = derive_status(roles)
    main = (
        roles.get('failed') or roles.get('broken') or roles.get('removed')
        or roles.get('interrupted') or roles.get('task') or roles.get('done')
        or roles.get('run')
    )
    t = Task(taskid=taskid, status=status, path=main or '',
             created_at=filename_timestamp(taskid))
    if main:
        try:
            t.mtime = os.path.getmtime(main)
        except OSError:
            pass
        if parse_content and os.path.exists(main):
            t.fields, t.failures, t.done_at = parse_file(main)
            # generic build tasks (PACKAGE=) group by the package name
            t.product = t.fields.get('PACKAGE') or product_group(t.fields.get('COMPONENTNAME', ''))
    return t


def scan_sales(sales_dir: str):
    """Скан очереди: ТОЛЬКО корень sales (без подкаталогов вроде old-tasks/),
    группировка файлов одного base в один Task."""
    by_base = {}
    try:
        with os.scandir(sales_dir) as it:
            for e in it:
                if not e.is_file():
                    continue
                base, role = split_base_ext(e.name)
                if role is None:
                    continue
                by_base.setdefault(base, {})[role] = e.path
    except FileNotFoundError:
        pass
    except OSError:
        pass
    return [_build_task(b, roles) for b, roles in by_base.items()]


def scan_done(done_dir: str, hours: int = 48):
    """Недавние завершённые: фильтр по mtime БЕЗ чтения, парсинг только свежих."""
    cutoff = time.time() - hours * 3600
    out = []
    try:
        with os.scandir(done_dir) as it:
            for e in it:
                if not e.name.endswith('.done') or not e.is_file():
                    continue
                try:
                    if e.stat().st_mtime < cutoff:
                        continue
                except OSError:
                    continue
                base, _ = split_base_ext(e.name)
                out.append(_build_task(base, {'done': e.path}))
    except FileNotFoundError:
        pass
    except OSError:
        pass
    return out


def find_task(taskid: str, sales_dir: str, done_dir: str):
    """Найти задачу по taskid в корне sales и в ~/done (для страницы деталей)."""
    roles = {}
    try:
        with os.scandir(sales_dir) as it:
            for e in it:
                if not e.is_file():
                    continue
                b, role = split_base_ext(e.name)
                if b == taskid and role:
                    roles[role] = e.path
    except (FileNotFoundError, OSError):
        pass
    p = os.path.join(done_dir, taskid + '.done')
    if os.path.exists(p):
        roles['done'] = p
    if not roles:
        return None
    return _build_task(taskid, roles)
