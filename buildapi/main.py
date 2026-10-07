"""korinf buildapi — HTTP API (по ключу) + web-интерфейс очереди ~/sales.

Запуск: python3 main.py  (или через systemd: uvicorn main:app --host 0.0.0.0 --port 5503)
"""
import os
import re
import random
import string
import pathlib
import datetime as dt
from enum import Enum
from typing import Any

from fastapi import FastAPI, Depends, HTTPException, Request, Query, Security, Path
from fastapi.responses import RedirectResponse, HTMLResponse, JSONResponse, PlainTextResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.security import APIKeyHeader
from pydantic import BaseModel

import taskreader as tr
import orders
import repair
import buildlogs
import repair_engines
import winebuild

BASE_DIR = pathlib.Path(__file__).resolve().parent


def load_config() -> dict:
    cfg = {
        'API_KEY': '', 'HOST': '0.0.0.0', 'PORT': '5503',
        'SALES_DIR': '/srv/builder/sales',
        'DONE_DIR': '/srv/builder/done',
        'DONE_HOURS': '48',
    }
    p = BASE_DIR / 'config'
    text = p.read_text(encoding='utf-8') if p.exists() else ''
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        k, v = line.split('=', 1)
        cfg[k.strip()] = tr._unquote(v.strip())
    cfg['DONE_HOURS'] = int(cfg.get('DONE_HOURS', 48) or 48)
    return cfg


CFG = load_config()
SALES, DONE = CFG['SALES_DIR'], CFG['DONE_DIR']
STOP_PATH = os.path.join(SALES, 'STOP')
QUEUE_LOG_PATH = '/var/log/queuebuild.log'
QUEUE_LOG_LINES = 300

app = FastAPI(
    title='korinf buildapi',
    version='1.3.0',
    description='Очередь сборок korinf (задачи из `~/sales`).\n\n'
                '**Аутентификация:** все `/api/*` требуют заголовок `X-API-Key` '
                '(значение — в `/srv/builder/Projects/korinf/buildapi/config`). '
                'Нажмите кнопку **Authorize** и вставьте ключ.\n\n'
                '**Web-интерфейс** (без ключа, для браузера): `/` — список по продуктам, '
                '`/task/{taskid}` — детали.',
)
templates = Jinja2Templates(directory=str(BASE_DIR / 'templates'))
templates.env.globals['repair_engines'] = repair_engines.ENGINES
app.mount('/static', StaticFiles(directory=str(BASE_DIR / 'static')), name='static')

templates.env.filters['ts2str'] = lambda v: (
    dt.datetime.fromtimestamp(v).strftime('%Y-%m-%d %H:%M') if v else '')


# ---------- типы ответов ----------
class TaskStatus(str, Enum):
    queued = 'queued'
    running = 'running'
    running_stale = 'running_stale'
    failed = 'failed'
    broken = 'broken'
    removed = 'removed'
    interrupted = 'interrupted'
    done = 'done'


class Failure(BaseModel):
    at: str | None = None
    error: str | None = None


class TaskOut(BaseModel):
    taskid: str
    status: str
    product: str = ''
    regnum: str = ''
    version: str = ''
    dist: str = ''
    componentname: str = ''
    package: str = ''
    fields: dict[str, Any] = {}
    failures: list[Failure] = []
    last_error: str | None = None
    done_at: str | None = None
    created_at: float | None = None
    path: str | None = None
    mtime: float | None = None


class SummaryOut(BaseModel):
    queue_stopped: bool
    total: int
    by_status: dict[str, int]
    by_product: dict[str, int]


class RestartOut(BaseModel):
    restarted: bool
    taskid: str
    new_path: str


class QueueStopOut(BaseModel):
    queue_stopped: bool
    created: bool


class QueueStartOut(BaseModel):
    queue_stopped: bool
    removed: bool


class BuildIn(BaseModel):
    package: str
    dist: str = 'all'
    targetdir: str | None = None
    force: bool = False


class RebuildIn(BaseModel):
    package: str
    arch: str = 'all'


class RepairIn(BaseModel):
    engine: str = repair_engines.DEFAULT


class BuildOut(BaseModel):
    taskid: str
    new_path: str


# package name must be safe for the shell argv built in robot/funcs/genericbuild
# (must not start with '-': bin/korinf would parse it as an option)
RE_PACKAGE = re.compile(r'^[A-Za-z0-9_][A-Za-z0-9._+-]*$')
# target system/list selector: all/ALL/x86_64/build/x86_64/ALTLinux/x86_64/Ubuntu/24.04
RE_DIST = re.compile(r'^[A-Za-z0-9][A-Za-z0-9/_.+-]*$')


def _gen_build_taskid() -> str:
    """RE_FILENAME-shaped name (B01D-0000 is valid hex) so _do_restart accepts the taskid."""
    ts = dt.datetime.now().strftime('%Y%m%d%H%M%S')
    rand = ''.join(random.choices(string.ascii_lowercase + string.digits, k=10))
    return f'{ts}.B01D-0000.{rand}'


# ---------- авторизация ----------
api_key_scheme = APIKeyHeader(name='X-API-Key', auto_error=False,
                              description='API-ключ из buildapi/config (кнопка Authorize справа)')


def require_api_key(key: str = Security(api_key_scheme)):
    if not CFG['API_KEY'] or key != CFG['API_KEY']:
        raise HTTPException(status_code=401, detail='invalid or missing X-API-Key')


def all_tasks():
    return tr.scan_sales(SALES) + tr.scan_done(DONE, CFG['DONE_HOURS'])


def queue_stopped() -> bool:
    return os.path.exists(STOP_PATH)


def _task_json(t: tr.Task) -> dict:
    return {
        'taskid': t.taskid, 'status': t.status, 'product': t.product,
        'regnum': t.fields.get('ETERREGNUM', ''),
        'version': t.fields.get('PROJECTVERSION', ''),
        'dist': t.fields.get('DIST', ''),
        'componentname': t.fields.get('COMPONENTNAME', ''),
        'package': t.fields.get('PACKAGE', ''),
        'fields': t.fields,
        'failures': [{'at': a, 'error': e} for a, e in t.failures],
        'last_error': t.failures[-1][1] if t.failures else None,
        'done_at': t.done_at, 'created_at': t.created_at,
        'path': t.path, 'mtime': t.mtime,
    }


def _do_restart(taskid: str) -> dict:
    """Перезапуск: <base>.task.failed -> <base>.task в корне ~/sales
    (атомарный rename; робот подхватит на следующем цикле)."""
    if not tr.RE_FILENAME.match(taskid + '.task'):
        raise HTTPException(400, 'bad taskid')
    src = os.path.join(SALES, taskid + '.task.failed')
    if not os.path.exists(src):
        raise HTTPException(404, 'no .task.failed in ~/sales for this taskid')
    dst = src[:-len('.failed')]
    try:
        # The worker knows the actual package paths, including distro symlinks.
        # Clear stale failure markers there before checking/building each package.
        fields, _, _ = tr.parse_file(src)
        if fields.get('CLEAR_FAILED_ON_RESTART') != '1':
            with open(src, 'a', encoding='utf-8') as task:
                task.write('\nCLEAR_FAILED_ON_RESTART=1\n')
        os.rename(src, dst)
    except OSError as e:
        raise HTTPException(500, f'restart failed: {e}')
    return {'restarted': True, 'taskid': taskid, 'new_path': dst}


# ===================== API (с ключом) =====================
@app.get('/api/summary',
         response_model=SummaryOut, tags=['Summary'], operation_id='get_summary',
         summary='Сводка по очереди сборок',
         description='Количество задач по статусам и продуктам + `queue_stopped` '
                     '(есть ли файл STOP в ~/sales — ставит робота на паузу).')
def api_summary(_: None = Depends(require_api_key)):
    tasks = all_tasks()
    by_status, by_product = {}, {}
    for t in tasks:
        by_status[t.status] = by_status.get(t.status, 0) + 1
        by_product[t.product] = by_product.get(t.product, 0) + 1
    return {'queue_stopped': queue_stopped(), 'total': len(tasks),
            'by_status': by_status, 'by_product': by_product}


@app.get('/api/tasks',
         response_model=list[TaskOut], tags=['Tasks'], operation_id='list_tasks',
         summary='Список задач (с фильтрами)',
         description='Активная очередь из ~/sales (`.task`/`.task.run`/`.task.failed`/...) '
                     'и недавние выполненные из ~/done за последние 48ч.')
def api_tasks(_: None = Depends(require_api_key),
              status: TaskStatus = Query(None, description='Фильтр по статусу'),
              product: str = Query(None, description='Фильтр по группе продукта, напр. `WINE@Etersoft`')):
    tasks = all_tasks()
    if status:
        tasks = [t for t in tasks if t.status == status.value]
    if product:
        tasks = [t for t in tasks if t.product == product]
    return [_task_json(t) for t in tasks]


@app.get('/api/task/{taskid}',
         response_model=TaskOut, tags=['Tasks'], operation_id='get_task',
         summary='Детали одной задачи',
         description='Все поля задачи (`fields`), история неудач (`failures` с датой и текстом Error) и `done_at`.')
def api_task(taskid: str = Path(..., description='Имя файла без расширения: '
                                                 '`YYYYMMDDhhmmss.<REGNUM>.<rand10>`'),
             _: None = Depends(require_api_key)):
    t = tr.find_task(taskid, SALES, DONE)
    if not t:
        raise HTTPException(404, 'task not found')
    return _task_json(t)


@app.post('/api/task/{taskid}/restart',
          response_model=RestartOut, tags=['Tasks'], operation_id='restart_task',
          summary='Перезапустить провалившуюся задачу',
          description='`.task.failed` → `.task` в корне ~/sales '
                      '(робот подхватит на следующем цикле, ~30с). Возвращает путь нового `.task`.')
def api_restart(taskid: str = Path(..., description='Имя файла задачи без расширения'),
                _: None = Depends(require_api_key)):
    return _do_restart(taskid)


@app.post('/api/queue/stop',
          response_model=QueueStopOut, tags=['Queue'], operation_id='stop_queue',
          summary='Остановить очередь (пауза робота)',
          description='Создаёт `~/sales/STOP` — робот встанет на паузу на следующей итерации.')
def api_queue_stop(_: None = Depends(require_api_key)):
    created = not os.path.exists(STOP_PATH)
    if created:
        pathlib.Path(STOP_PATH).touch()
    return {'queue_stopped': True, 'created': created}


@app.post('/api/queue/start',
          response_model=QueueStartOut, tags=['Queue'], operation_id='start_queue',
          summary='Запустить очередь',
          description='Удаляет `~/sales/STOP`.')
def api_queue_start(_: None = Depends(require_api_key)):
    removed = os.path.exists(STOP_PATH)
    if removed:
        try:
            os.remove(STOP_PATH)
        except OSError as e:
            raise HTTPException(500, f'cannot remove STOP: {e}')
    return {'queue_stopped': False, 'removed': removed}


@app.post('/api/build',
          response_model=BuildOut, tags=['Build'], operation_id='enqueue_build',
          summary='Поставить в очередь сборку произвольного пакета',
          description='Создаёт в `~/sales` `.task` с полями `PACKAGE`/`DIST` — робот соберёт '
                      'указанный пакет (`eepm`, `lavtomate-mcp`, …) для запрошенной системы или '
                      'списка (`all`, `ALL`, `x86_64/build`, `x86_64/ALTLinux`, …) через '
                      '`bin/korinf`. Имя файла соответствует схеме, поэтому задача сразу видна '
                      'в `/api/tasks`. Старые отметки провала пакета очищаются перед сборкой '
                      'по умолчанию; force=true дополнительно требует пересборку. '
                      'Робот подхватит её на следующем цикле (~30с).')
def api_enqueue_build(body: BuildIn, _: None = Depends(require_api_key)):
    if not RE_PACKAGE.match(body.package):
        raise HTTPException(400, 'invalid package name (A-Z a-z 0-9 . _ + -, must not start with -)')
    if not RE_DIST.match(body.dist):
        raise HTTPException(400, 'invalid dist (use all/ALL/x86_64/build/x86_64/ALTLinux/x86_64/Ubuntu/24.04)')
    if body.targetdir and not body.targetdir.startswith('/'):
        raise HTTPException(400, 'targetdir must be an absolute path')
    if body.targetdir and ' ' in body.targetdir:
        raise HTTPException(400, 'targetdir must not contain spaces (bin/korinf re-splits args)')
    taskid = _gen_build_taskid()
    # double-quoted values match the convention tools/arobot-retouch.sh greps for (DIST="...")
    lines = [f'PACKAGE="{body.package}"', f'DIST="{body.dist}"', 'TASKTYPE=build']
    if body.targetdir:
        lines.append(f'TARGETDIR="{body.targetdir}"')
    if body.force:
        lines.append('FORCE=1')
    lines.append('CLEAR_FAILED_ON_RESTART=1')
    # write atomically (tmp + rename) so the worker never observes a partial/empty file
    path = os.path.join(SALES, taskid + '.task')
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
        raise HTTPException(500, f'cannot write task: {e}')
    return {'taskid': taskid, 'new_path': path}


@app.post('/api/rebuild', response_model=BuildOut, tags=['Build'],
          operation_id='rebuild_package', summary='Пересобрать общий пакет для архитектуры или all',
          description='Принудительная пересборка пакета (например eepm). arch=all — цели '
                      'пакета из distro.list; отдельная архитектура — её список build. '
                      'Статус задания доступен через /api/task/{taskid}. Требуется X-API-Key.')
def api_rebuild(body: RebuildIn, _: None = Depends(require_api_key)):
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]*', body.arch):
        raise HTTPException(400, 'invalid architecture')
    if body.arch != 'all' and not (BASE_DIR.parent / 'etc/lists' / body.arch / 'build').is_file():
        raise HTTPException(400, 'architecture has no configured build list')
    dist = 'all' if body.arch == 'all' else f'{body.arch}/build'
    return api_enqueue_build(BuildIn(package=body.package, dist=dist, force=True))


def _start_repair(taskid, engine=repair_engines.DEFAULT):
    if not repair.TASK_ID.fullmatch(taskid):
        raise HTTPException(400, 'bad taskid')
    task = tr.find_task(taskid, SALES, DONE)
    if not task:
        raise HTTPException(404, 'task not found')
    try:
        return repair.start(task, BASE_DIR.parent, engine=engine)
    except repair.RepairError as exc:
        raise HTTPException(exc.status, str(exc))


@app.post('/api/task/{taskid}/repair', tags=['Repair'], status_code=202,
          summary='Исправить сборку через MiMo или Codex',
          description='JSON: {"engine":"mimo"} или {"engine":"codex"}. По умолчанию MiMo.')
def api_repair(taskid: str, body: RepairIn | None = None, _: None = Depends(require_api_key)):
    return _start_repair(taskid, body.engine if body else repair_engines.DEFAULT)


@app.get('/api/task/{taskid}/repair', tags=['Repair'], summary='Статус и отчёт ремонта')
def api_repair_status(taskid: str, _: None = Depends(require_api_key)):
    result = repair.status(taskid)
    if not result:
        raise HTTPException(404, 'repair not found')
    return result


def _repair_log(taskid):
    try:
        result = repair.progress(taskid)
    except repair.RepairError as exc:
        raise HTTPException(exc.status, str(exc))
    except OSError:
        raise HTTPException(503, 'Журнал временно недоступен')
    if not result:
        raise HTTPException(404, 'repair not found')
    return JSONResponse(result, headers={'Cache-Control': 'no-store'})


@app.get('/api/task/{taskid}/repair/log', tags=['Repair'], summary='Живой журнал ремонта')
def api_repair_log(taskid: str, _: None = Depends(require_api_key)):
    return _repair_log(taskid)


@app.get('/task/{taskid}/repair/log', include_in_schema=False)
def web_repair_log(taskid: str):
    return _repair_log(taskid)


class WineOrderIn(BaseModel):
    principal: str
    version: str
    dist: str


@app.get('/api/wine/versions', tags=['Wine orders'], dependencies=[Depends(require_api_key)])
def wine_versions():
    return orders.versions()


@app.get('/api/wine/distributions', tags=['Wine orders'], dependencies=[Depends(require_api_key)])
def wine_distributions(version: str, principal: str):
    profile = orders.profile(principal, DONE)
    return orders.distributions(version, orders.product_type(profile['COMPONENTNAME']))


@app.get('/api/wine/orders', tags=['Wine orders'], dependencies=[Depends(require_api_key)])
def wine_orders(principal: str):
    return orders.history(principal, SALES, DONE)


@app.post('/api/wine/orders', tags=['Wine orders'], dependencies=[Depends(require_api_key)],
          description='Trusted Kerberos gateway supplies principal; never take it from an unauthenticated browser.')
def wine_order(body: WineOrderIn):
    return orders.enqueue(body.principal, body.version, body.dist, SALES, DONE)


class WineBuildIn(BaseModel):
    version: str
    dist: str
    force: bool = False


class ProductBuildIn(WineBuildIn):
    product: str = winebuild.DEFAULT_PRODUCT


class WineBuildOut(BaseModel):
    taskid: str
    new_path: str
    existing: bool


def _winebuild(function, *args):
    try:
        return function(*args)
    except winebuild.WineBuildError as exc:
        raise HTTPException(exc.status, str(exc))


@app.post('/api/wine/build', response_model=WineBuildOut, tags=['Wine build'],
          operation_id='enqueue_wine_build', summary='Собрать WINE@Etersoft для системы версии',
          description='Ставит в очередь задачу TASKTYPE=winebuild: робот выполнит '
                      '`wine-etersoft-bootstrap-new.sh [--force] <dist> <version>` (version — каталог '
                      'WINE@Etersoft, напр. `11-testing`; dist — система из его distro.list). '
                      'Задачи выполняются по одной; если такая же задача уже в очереди или '
                      'собирается, возвращается она (`existing: true`). Этапы — '
                      '`/api/task/{taskid}/progress`, лог — `/api/task/{taskid}/log`.')
def api_wine_build(body: WineBuildIn, _: None = Depends(require_api_key)):
    return _winebuild(winebuild.enqueue, body.version, body.dist, body.force, SALES, _gen_build_taskid())


@app.post('/api/product/build', response_model=WineBuildOut, tags=['Wine build'],
          operation_id='enqueue_product_build', summary='Собрать продукт для системы версии',
          description='Как /api/wine/build для продукта: WINE@Etersoft, RX@Etersoft или CRYPTO@Etersoft '
                      '(version — каталог продукта с distro.list, напр. `1.10`, `unstable`, `0.5`). '
                      'Робот выполняет сценарий сборки системы продукта.')
def api_product_build(body: ProductBuildIn, _: None = Depends(require_api_key)):
    return _winebuild(winebuild.enqueue, body.version, body.dist, body.force, SALES, _gen_build_taskid(),
                      body.product)


@app.get('/api/wine/systems', tags=['Wine build'], summary='Системы версии WINE@Etersoft из её distro.list')
def api_wine_systems(version: str, _: None = Depends(require_api_key)):
    return _winebuild(winebuild.systems, version)


@app.get('/api/product/systems', tags=['Wine build'], summary='Системы версии продукта из её distro.list')
def api_product_systems(version: str, product: str = winebuild.DEFAULT_PRODUCT,
                        _: None = Depends(require_api_key)):
    return _winebuild(winebuild.systems, version, product)


@app.get('/api/task/{taskid}/progress', tags=['Wine build'], summary='Этапы сборки winebuild-задачи',
         description='Составляющие (package, dist) со временем начала, длительностью, '
                     'результатом ok/skipped/failed и шагами; `current` — идущая составляющая.')
def api_task_progress(taskid: str, _: None = Depends(require_api_key)):
    result = _winebuild(winebuild.progress, SALES, taskid)
    if result is None:
        raise HTTPException(404, 'no progress for this task (not a winebuild task or not started)')
    return result


def _task_log(taskid, tail):
    text = _winebuild(winebuild.log_tail, SALES, taskid, tail)
    if text is None:
        raise HTTPException(404, 'no log for this task')
    return PlainTextResponse(text, headers={'Cache-Control': 'no-store'})


@app.get('/api/task/{taskid}/log', tags=['Wine build'], summary='Конец лога winebuild-задачи',
         response_class=PlainTextResponse)
def api_task_log(taskid: str, tail: int = Query(winebuild.LOG_TAIL, ge=1, le=1024 * 1024),
                 _: None = Depends(require_api_key)):
    return _task_log(taskid, tail)


# ===================== Web (без ключа, не входит в схему API) =====================
STATUS_ORDER = ['running', 'running_stale', 'queued', 'failed',
                'broken', 'removed', 'interrupted', 'done']


@app.get('/', response_class=HTMLResponse, include_in_schema=False)
def web_index(request: Request, product: str = None):
    tasks = all_tasks()
    products = sorted({t.product for t in tasks})
    if product:
        tasks = [t for t in tasks if t.product == product]
    groups = {}
    for t in tasks:
        groups.setdefault(t.product, {}).setdefault(t.status, []).append(t)
    for g in groups.values():
        for s in g:
            g[s].sort(key=lambda x: x.created_at or 0)
    repairs = {t.taskid: repair.status(t.taskid) for t in tasks}
    return templates.TemplateResponse(request, 'index.html', {
        'groups': groups, 'queue_stopped': queue_stopped(),
        'products': products, 'current_product': product,
        'status_order': STATUS_ORDER,
        'repairs': repairs,
        'has_repair': any(r and r['status'] in repair.ACTIVE for r in repairs.values()),
        'has_running': any(t.status in ('running', 'running_stale') for t in tasks),
    })


@app.get('/queue-log', response_class=HTMLResponse, include_in_schema=False)
def web_queue_log(request: Request):
    try:
        with open(QUEUE_LOG_PATH, encoding='utf-8', errors='replace') as f:
            lines = f.readlines()[-QUEUE_LOG_LINES:]
        log = ''.join(lines)
    except OSError as e:
        log = f'Unable to read queue log: {e}'
    return templates.TemplateResponse(request, 'queue_log.html', {
        'log': log, 'line_count': len(log.splitlines()),
        'queue_stopped': queue_stopped(), 'has_running': False,
    })


@app.get('/task/{taskid}', response_class=HTMLResponse, include_in_schema=False)
def web_task(request: Request, taskid: str):
    t = tr.find_task(taskid, SALES, DONE)
    if not t:
        raise HTTPException(404, 'task not found')
    result = repair.status(taskid)
    return templates.TemplateResponse(request, 'task.html', {
        'task': t, 'queue_stopped': queue_stopped(),
        'repair': result, 'has_repair': bool(result and result['status'] in repair.ACTIVE),
        'live_repair': bool(result),
        'build_logs': buildlogs.discover(t),
        'progress': winebuild.progress(SALES, taskid) if winebuild.is_winebuild(t) else None,
        'has_running': t.status in ('running', 'running_stale'),
    })


@app.get('/task/{taskid}/log', response_class=PlainTextResponse, include_in_schema=False)
def web_task_log(taskid: str):
    return _task_log(taskid, 1024 * 1024)


@app.post('/task/{taskid}/restart', include_in_schema=False)
def web_restart(taskid: str):
    _do_restart(taskid)
    return RedirectResponse(url=f'/task/{taskid}', status_code=303)


def _task_logs(taskid):
    if not repair.TASK_ID.fullmatch(taskid):
        raise HTTPException(400, 'bad taskid')
    task = tr.find_task(taskid, SALES, DONE)
    if not task:
        raise HTTPException(404, 'task not found')
    return buildlogs.discover(task)


@app.get('/api/task/{taskid}/logs', tags=['Tasks'], summary='Логи составляющих задания')
def api_task_logs(taskid: str, _: None = Depends(require_api_key)):
    return _task_logs(taskid)


@app.get('/task/{taskid}/logs/{logid}', response_class=HTMLResponse, include_in_schema=False)
def web_build_log(request: Request, taskid: str, logid: str):
    entry = next((row for row in _task_logs(taskid) if row['id'] == logid), None)
    if not entry:
        raise HTTPException(404, 'build log not found')
    try:
        content = buildlogs.read_tail(entry['path'])
    except (OSError, EOFError, ValueError) as exc:
        raise HTTPException(422, f'cannot read build log: {exc}')
    return templates.TemplateResponse(request, 'build_log.html', {
        'entry': entry, 'log': content, 'taskid': taskid,
        'queue_stopped': queue_stopped(), 'has_running': False,
    })


@app.post('/task/{taskid}/repair', include_in_schema=False)
async def web_repair(request: Request, taskid: str):
    # Browser forms are same-origin; reject cross-site attempts to start a paid job.
    from urllib.parse import urlsplit, parse_qs
    origin = request.headers.get('origin')
    if (origin and urlsplit(origin).netloc != request.headers.get('host')) or \
            request.headers.get('sec-fetch-site') == 'cross-site':
        raise HTTPException(403, 'cross-origin repair is not allowed')
    try:
        try:
            form = parse_qs((await request.body()).decode('utf-8'), max_num_fields=4)
        except (ValueError, UnicodeDecodeError):
            raise HTTPException(400, 'Некорректная форма')
        engine = form.get('engine', [repair_engines.DEFAULT])[0]
        _start_repair(taskid, engine)
    except HTTPException as exc:
        return templates.TemplateResponse(request, 'repair_error.html', {
            'taskid': taskid, 'message': exc.detail, 'queue_stopped': queue_stopped(),
            'has_running': False,
        }, status_code=exc.status_code)
    return RedirectResponse(url=f'/task/{taskid}#repair', status_code=303)


@app.post('/queue/stop', include_in_schema=False)
def web_queue_stop():
    if not os.path.exists(STOP_PATH):
        pathlib.Path(STOP_PATH).touch()
    return RedirectResponse(url='/', status_code=303)


@app.post('/queue/start', include_in_schema=False)
def web_queue_start():
    if os.path.exists(STOP_PATH):
        os.remove(STOP_PATH)
    return RedirectResponse(url='/', status_code=303)


if __name__ == '__main__':
    import uvicorn
    uvicorn.run('main:app', host=CFG['HOST'], port=int(CFG['PORT']),
                reload=False, log_level='info')
