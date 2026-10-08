"""Personal delivery orders of the products of robot/products.list.
Identity is supplied by the authenticated API gateway."""
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
import products
import taskreader as tr

ROOT = Path(__file__).resolve().parent.parent
STATE = ROOT / 'buildapi/order-state'
# a product's versions are <root>/<product>, delivered to DOWNLOAD_ROOT/<product>
ETERSOFT_PUB = Path('/var/ftp/pub/Etersoft')
ETERSOFT_PVT = Path('/var/ftp/pvt/Etersoft')
DOWNLOAD_ROOT = Path('/var/ftp/pub/download')
SAFE = re.compile(r'[A-Za-z0-9][A-Za-z0-9_.+-]*\Z')
_cache = {}
_cache_lock = threading.Lock()


def check_product(product):
    if not products.get(product):
        raise HTTPException(400, 'Неизвестный продукт')
    return product


def roots(product):
    """pub, pvt and delivery roots of a product."""
    return ETERSOFT_PUB / product, ETERSOFT_PVT / product, DOWNLOAD_ROOT / product


def identity(principal):
    match = re.fullmatch(r'([A-Za-z0-9][A-Za-z0-9._-]*)@ETERSOFT\.RU', principal, re.I)
    if not match:
        raise HTTPException(403, 'Требуется учётная запись ETERSOFT.RU')
    return match[1].lower() + '@etersoft.ru'


def license_type(component, product):
    """The license type an order names in COMPONENTNAME (products with license_types=1)."""
    for name, kind in [('Network Lite', 'NetworkLite'), ('Network', 'Network'),
                       ('Local', 'Local'), ('SQL', 'SQL'), ('CAD', 'CAD'),
                       ('School', 'School'), ('PREMIUM', 'PREMIUM'), ('Enterprise', 'Network')]:
        if name in component:
            return kind
    if component in (product, product + ' ('):
        return 'Network'
    raise HTTPException(409, 'Неизвестный тип продукта в старом заказе')


def profile(principal, done, product):
    email = identity(principal)
    # Newest orders first; cache only a matching personal profile, never all customers.
    key = (str(done), email, product)
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
        if not fields.get('COMPONENTNAME', '').startswith(product):
            continue
        if not re.fullmatch(r'[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}', fields.get('ETERREGNUM', '')):
            continue
        if not all(fields.get(k) for k in ('PRODUCT', 'TYPE_LICENSE', 'FULLNAME')):
            continue
        if products.get(product)['license_types']:
            license_type(fields['COMPONENTNAME'], product)
        with _cache_lock:
            _cache[key] = (time.monotonic(), fields)
        return dict(fields)
    raise HTTPException(404, f'В done не найден выполненный заказ {product} на вашу почту')


def versions(product):
    """Versions of a product's version.list that can be delivered."""
    check_product(product)
    pub, pvt, _ = roots(product)
    result = []
    try:
        lines = (pub / 'version.list').read_text().splitlines()
    except OSError:
        return result
    for raw in lines:
        if not raw.strip() or raw.lstrip().startswith('#'):
            continue
        parts = re.split(r'\t+| {2,}', raw.strip())
        if len(parts) < 2:
            continue
        version = parts[1]
        if not SAFE.fullmatch(version) or not (pvt / version).is_dir():
            continue
        if (pub / version / 'distro.list').is_file():
            result.append({'version': version, 'label': parts[0].rstrip(':'), 'default': '*' in parts[2:]})
    return result


def all_versions():
    """Every product's versions for one choice: [{'product', 'version', 'label', 'default'}]."""
    return [dict(v, product=p) for p in products.names() for v in versions(p)]


def distributions(version, product):
    if version not in {v['version'] for v in versions(product)}:
        raise HTTPException(400, f'Неизвестная версия {product}')
    pub, _, _ = roots(product)
    result = set()
    # The version's supported targets include systems awaiting their first build.
    for raw in (pub / version / 'distro.list').read_text().splitlines():
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
    # records written before the orders of other products had no product
    product = record.get('product', 'WINE@Etersoft')
    result = {k: record[k] for k in ('taskid', 'version', 'dist', 'created_at')}
    result['product'] = product
    result.update(status=task.status if task else 'unknown', download_url=None, install_url=None)
    rel = task.fields.get('WEB_DOWNLOAD_REL', '') if task else ''
    parts = rel.split('/')
    if rel and all(SAFE.fullmatch(p) for p in parts):
        downloads = roots(product)[2]
        directory = downloads.joinpath(*parts)
        if directory.resolve().is_relative_to(downloads.resolve()):
            ready = directory / ('.order-' + record['taskid'] + '.ready')
            # a product taken out of products.list: its deliveries are still shown
            settings = products.get(product) or products.parse(product)[product]
            if ready.is_file() and all((directory / name).is_file() for name in settings['required']):
                result['status'] = 'ready'
                base = settings['download_url'].replace('{product}', quote(product))
                result['download_url'] = base + quote(rel, safe='/') + '/'
                if settings['install']:
                    result['install_url'] = result['download_url'] + settings['install']
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


def enqueue(principal, version, dist, sales, done, product):
    email = identity(principal)
    check_product(product)
    fields = profile(principal, done, product)
    if dist not in distributions(version, product):
        raise HTTPException(400, 'Дистрибутив недоступен для этой версии')
    folder = STATE / email
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (folder / '.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for previous in history(principal, sales, done):
            if previous['product'] == product and previous['version'] == version and previous['dist'] == dist \
                    and previous['status'] in ('queued', 'running', 'running_stale'):
                return previous
        taskid = dt.datetime.now().strftime('%Y%m%d%H%M%S') + '.' + fields['ETERREGNUM'] + '.' + secrets.token_hex(5)
        keep = ('PRODUCT', 'COMPONENTNAME', 'ETERREGNUM', 'MAILTO', 'FULLNAME',
                'TYPE_LICENSE', 'NAME_LICENSE', 'COUNT_LICENSE', 'OWNER', 'DATE_START', 'DATE_END', 'SERVICE_END')
        fields = {k: fields[k] for k in keep if k in fields}
        fields.update(PROJECTVERSION=version, DIST=dist, CLEAR_FAILED_ON_RESTART='1',
                      RELEASECANDIDAT='1' if 'testing' in version or 'unstable' in version else '0',
                      WEB_ORDER_USER=email, WEB_ORDER_ID=taskid)
        if products.get(product)['downloaddir']:
            # the robot takes the version directory of the product from DOWNLOADDIR
            fields['DOWNLOADDIR'] = f'{product}/{version}'
        content = ''.join(k + '=' + shell_value(v) + '\n' for k, v in fields.items())
        record = dict(taskid=taskid, user=email, product=product, version=version, dist=dist, created_at=time.time())
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
