"""Personal Wine delivery orders. Identity is supplied by the authenticated API gateway."""
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import re
import secrets
import threading
import time
from urllib.parse import quote

from fastapi import HTTPException
import taskreader as tr

ROOT = Path(__file__).resolve().parent.parent
PUB = Path('/var/ftp/pub/Etersoft/WINE@Etersoft')
PVT = Path('/var/ftp/pvt/Etersoft/WINE@Etersoft')
DOWNLOADS = Path('/var/ftp/pub/download/WINE@Etersoft')
STATE = ROOT / 'buildapi/order-state'
DOWNLOAD_URL = 'https://download.etersoft.ru/W@E/'
SAFE = re.compile(r'[A-Za-z0-9][A-Za-z0-9_.+-]*\Z')
_cache = {}
_cache_lock = threading.Lock()


def identity(principal):
    match = re.fullmatch(r'([A-Za-z0-9][A-Za-z0-9._-]*)@ETERSOFT\.RU', principal, re.I)
    if not match:
        raise HTTPException(403, 'Требуется учётная запись ETERSOFT.RU')
    return match[1].lower() + '@etersoft.ru'


def product_type(component):
    for name, kind in [('Network Lite', 'NetworkLite'), ('Network', 'Network'),
                       ('Local', 'Local'), ('SQL', 'SQL'), ('CAD', 'CAD'),
                       ('School', 'School'), ('PREMIUM', 'PREMIUM'), ('Enterprise', 'Network')]:
        if name in component:
            return kind
    if component in ('WINE@Etersoft', 'WINE@Etersoft ('):
        return 'Network'
    raise HTTPException(409, 'Неизвестный тип продукта в старом заказе')


def profile(principal, done):
    email = identity(principal)
    # Newest orders first; cache only a matching personal profile, never all customers.
    key = (str(done), email)
    with _cache_lock:
        cached = _cache.get(key)
        if cached and time.monotonic() - cached[0] < 60:
            return dict(cached[1])
    for path in sorted(Path(done).glob('*.done'), reverse=True):
        try:
            fields, _, finished = tr.parse_file(str(path))
        except OSError:
            continue
        if not finished or fields.get('MAILTO', '').lower() != email:
            continue
        if not fields.get('COMPONENTNAME', '').startswith('WINE@Etersoft'):
            continue
        if not re.fullmatch(r'[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}', fields.get('ETERREGNUM', '')):
            continue
        if not all(fields.get(k) for k in ('PRODUCT', 'TYPE_LICENSE', 'FULLNAME')):
            continue
        product_type(fields['COMPONENTNAME'])
        with _cache_lock:
            _cache[key] = (time.monotonic(), fields)
        return dict(fields)
    raise HTTPException(404, 'В done не найден выполненный заказ WINE@Etersoft на вашу почту')


def versions():
    result = []
    for raw in (PUB / 'version.list').read_text().splitlines():
        if not raw.strip() or raw.lstrip().startswith('#'):
            continue
        parts = re.split(r'\t+| {2,}', raw.strip())
        if len(parts) < 2:
            continue
        version = parts[1]
        if SAFE.fullmatch(version) and (PUB / version / 'WINE').is_dir() and (PVT / version).is_dir():
            result.append({'version': version, 'label': parts[0].rstrip(':'), 'default': '*' in parts[2:]})
    return result


def distributions(version, kind):
    if version not in {v['version'] for v in versions()}:
        raise HTTPException(400, 'Неизвестная версия WINE@Etersoft')
    result = set()
    # The version's supported targets include systems awaiting their first build.
    for raw in (PUB / version / 'distro.list').read_text().splitlines():
        line = raw.split('#', 1)[0].strip()
        if not line:
            continue
        value = line.split()[0]
        parts = value.split('/')
        if len(parts) == 3 and parts[0] == 'x86_64' and all(SAFE.fullmatch(p) for p in parts):
            result.add(value)
    return sorted(result, key=str.casefold)


def _write_json(path, data):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(data, ensure_ascii=False))
    os.replace(temporary, path)


def _task(taskid, sales, done):
    roles = {}
    for suffix, role in tr.EXT_ROLES.items():
        path = Path(sales) / (taskid + suffix)
        if path.is_file():
            roles[role] = str(path)
    path = Path(done) / (taskid + '.done')
    if path.is_file():
        roles['done'] = str(path)
    return tr._build_task(taskid, roles) if roles else None


def status(record, sales, done):
    task = _task(record['taskid'], sales, done)
    result = {k: record[k] for k in ('taskid', 'version', 'dist', 'created_at')}
    result.update(status=task.status if task else 'unknown', download_url=None, install_url=None)
    rel = task.fields.get('WEB_DOWNLOAD_REL', '') if task else ''
    parts = rel.split('/')
    if rel and all(SAFE.fullmatch(p) for p in parts):
        directory = DOWNLOADS.joinpath(*parts)
        if directory.resolve().is_relative_to(DOWNLOADS.resolve()):
            ready = directory / ('.order-' + record['taskid'] + '.ready')
            required = ['wine-etersoft.lic', 'wine-etersoft-install.sh', 'wine-etersoft-install.sha256']
            if ready.is_file() and all((directory / name).is_file() for name in required):
                result['status'] = 'ready'
                result['download_url'] = DOWNLOAD_URL + quote(rel, safe='/') + '/'
                result['install_url'] = result['download_url'] + 'wine-etersoft-install.sh'
            elif task.status == 'done':
                result['status'] = 'expired'
    if task and task.status == 'done' and not rel:
        result['status'] = 'unavailable'
    return result


def history(principal, sales, done):
    email = identity(principal)
    folder = STATE / email
    result = []
    for path in sorted(folder.glob('*.json'), reverse=True):
        record = json.loads(path.read_text())
        if record['user'] == email:
            result.append(status(record, sales, done))
    return result


def shell_value(value):
    # Robot sources assignments: escape expansion and quoting inside double quotes.
    if any(c in value for c in '\n\r\x00'):
        raise HTTPException(409, 'Перенос строки или нулевой байт в данных старого заказа')
    return '"' + ''.join('\\' + c if c in '\\$`"' else c for c in value) + '"'


def enqueue(principal, version, dist, sales, done):
    email = identity(principal)
    fields = profile(principal, done)
    if dist not in distributions(version, product_type(fields['COMPONENTNAME'])):
        raise HTTPException(400, 'Дистрибутив недоступен для этой версии')
    folder = STATE / email
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (folder / '.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for previous in history(principal, sales, done):
            if previous['version'] == version and previous['dist'] == dist and previous['status'] in ('queued', 'running', 'running_stale'):
                return previous
        taskid = dt.datetime.now().strftime('%Y%m%d%H%M%S') + '.' + fields['ETERREGNUM'] + '.' + secrets.token_hex(5)
        keep = ('PRODUCT', 'COMPONENTNAME', 'ETERREGNUM', 'MAILTO', 'FULLNAME',
                'TYPE_LICENSE', 'NAME_LICENSE', 'COUNT_LICENSE', 'OWNER', 'DATE_START', 'DATE_END', 'SERVICE_END')
        fields = {k: fields[k] for k in keep if k in fields}
        fields.update(PROJECTVERSION=version, DIST=dist, CLEAR_FAILED_ON_RESTART='1',
                      RELEASECANDIDAT='1' if 'testing' in version or 'unstable' in version else '0',
                      WEB_ORDER_USER=email, WEB_ORDER_ID=taskid)
        content = ''.join(k + '=' + shell_value(v) + '\n' for k, v in fields.items())
        record = dict(taskid=taskid, user=email, version=version, dist=dist, created_at=time.time())
        record_path = folder / (taskid + '.json')
        queued = Path(sales) / (taskid + '.task')
        temporary = queued.with_suffix('.tmp')
        _write_json(record_path, record)
        try:
            with temporary.open('x') as stream:
                stream.write(content)
            os.replace(temporary, queued)
        except OSError:
            temporary.unlink(missing_ok=True)
            record_path.unlink(missing_ok=True)
            raise
        return status(record, sales, done)
