"""korinf buildapi — HTTP API (по ключу) + web-интерфейс очереди ~/sales.

Запуск: python3 main.py  (или через systemd: uvicorn main:app --host 0.0.0.0 --port 8080)
"""
import os
import shutil
import pathlib
import datetime as dt
from enum import Enum
from typing import Any

from fastapi import FastAPI, Depends, HTTPException, Request, Query, Security, Path
from fastapi.responses import RedirectResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.security import APIKeyHeader
from pydantic import BaseModel

import taskreader as tr

BASE_DIR = pathlib.Path(__file__).resolve().parent


def load_config() -> dict:
    cfg = {
        'API_KEY': '', 'HOST': '0.0.0.0', 'PORT': '8080',
        'SALES_DIR': '/srv/builder/sales',
        'DONE_DIR': '/srv/builder/done',
        'OLD_TASKS_DIR': '/srv/builder/sales/old-tasks',
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
SALES, DONE, OLD = CFG['SALES_DIR'], CFG['DONE_DIR'], CFG['OLD_TASKS_DIR']
STOP_PATH = os.path.join(SALES, 'STOP')

app = FastAPI(
    title='korinf buildapi',
    version='1.1.0',
    description='Очередь сборок korinf (задачи из `~/sales`).\n\n'
                '**Аутентификация:** все `/api/*` требуют заголовок `X-API-Key` '
                '(значение — в `/srv/builder/Projects/korinf/buildapi/config`). '
                'Нажмите кнопку **Authorize** и вставьте ключ.\n\n'
                '**Web-интерфейс** (без ключа, для браузера): `/` — список по продуктам, '
                '`/task/{taskid}` — детали.',
)
templates = Jinja2Templates(directory=str(BASE_DIR / 'templates'))
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


# ---------- авторизация ----------
api_key_scheme = APIKeyHeader(name='X-API-Key', auto_error=False,
                              description='API-ключ из buildapi/config (кнопка Authorize справа)')


def require_api_key(key: str = Security(api_key_scheme)):
    if not CFG['API_KEY'] or key != CFG['API_KEY']:
        raise HTTPException(status_code=401, detail='invalid or missing X-API-Key')


def all_tasks():
    return tr.scan_sales(SALES, OLD) + tr.scan_done(DONE, CFG['DONE_HOURS'])


def queue_stopped() -> bool:
    return os.path.exists(STOP_PATH)


def _task_json(t: tr.Task) -> dict:
    return {
        'taskid': t.taskid, 'status': t.status, 'product': t.product,
        'regnum': t.fields.get('ETERREGNUM', ''),
        'version': t.fields.get('PROJECTVERSION', ''),
        'dist': t.fields.get('DIST', ''),
        'componentname': t.fields.get('COMPONENTNAME', ''),
        'fields': t.fields,
        'failures': [{'at': a, 'error': e} for a, e in t.failures],
        'last_error': t.failures[-1][1] if t.failures else None,
        'done_at': t.done_at, 'created_at': t.created_at,
        'path': t.path, 'mtime': t.mtime,
    }


def _do_restart(taskid: str) -> dict:
    """Перезапуск: <base>.task.failed -> <base>.task.

    Если .task.failed лежит в old-tasks/, копируем его в корень sales/
    (робот читает только корень), затем атомарно переименовываем в .task.
    """
    if not tr.RE_FILENAME.match(taskid + '.task'):
        raise HTTPException(400, 'bad taskid')
    src = None
    for d in (SALES, OLD):
        cand = os.path.join(d, taskid + '.task.failed')
        if os.path.exists(cand):
            src = cand
            break
    if not src:
        raise HTTPException(404, 'no .task.failed for this taskid')
    if os.path.commonpath([os.path.abspath(src), os.path.abspath(OLD)]) == os.path.abspath(OLD):
        dst_failed = os.path.join(SALES, taskid + '.task.failed')
        try:
            shutil.copy2(src, dst_failed)
        except OSError as e:
            raise HTTPException(500, f'cannot copy from old-tasks: {e}')
        src = dst_failed
    dst = src[:-len('.failed')]
    try:
        os.rename(src, dst)
    except OSError as e:
        raise HTTPException(500, f'rename failed: {e}')
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
    t = tr.find_task(taskid, SALES, OLD, DONE)
    if not t:
        raise HTTPException(404, 'task not found')
    return _task_json(t)


@app.post('/api/task/{taskid}/restart',
          response_model=RestartOut, tags=['Tasks'], operation_id='restart_task',
          summary='Перезапустить провалившуюся задачу',
          description='`.task.failed` → `.task` (робот подхватит на следующем цикле, ~30с). '
                      'Если файл лежит в `old-tasks/`, он копируется в корень ~/sales '
                      '(робот читает только корень). Возвращает путь нового `.task`.')
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
    return templates.TemplateResponse(request, 'index.html', {
        'groups': groups, 'queue_stopped': queue_stopped(),
        'products': products, 'current_product': product,
        'status_order': STATUS_ORDER,
        'has_running': any(t.status in ('running', 'running_stale') for t in tasks),
    })


@app.get('/task/{taskid}', response_class=HTMLResponse, include_in_schema=False)
def web_task(request: Request, taskid: str):
    t = tr.find_task(taskid, SALES, OLD, DONE)
    if not t:
        raise HTTPException(404, 'task not found')
    return templates.TemplateResponse(request, 'task.html', {
        'task': t, 'queue_stopped': queue_stopped(),
        'has_running': t.status in ('running', 'running_stale'),
    })


@app.post('/task/{taskid}/restart', include_in_schema=False)
def web_restart(taskid: str):
    _do_restart(taskid)
    return RedirectResponse(url=f'/task/{taskid}', status_code=303)


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
