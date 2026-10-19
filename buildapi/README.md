# Korinf web and API

The build queue of Korinf on builder64: http://builder64.office.etersoft.ru:5503.
The web pages (`/`, `/task/{taskid}`) need no key and use the internal-network
access model, without individual accounts. `/api/*` requires the `X-API-Key`
header.

This guide is served as `/help` (HTML) and `/help.md` (Markdown); `/llms.txt` is
a short index for programs and AI agents; `/docs` (Swagger UI), `/redoc` and
`/openapi.json` describe every API path.

## Getting the API key

The key is given to the members of group `korinfbuilder` on builder64 over ssh:

```sh
ssh builder64.office.etersoft.ru /srv/builder/Projects/korinf/tools/korinf-api-key > ~/.config/korinf-api.key
chmod 600 ~/.config/korinf-api.key
```

Without the group the command says whom to ask (the builder64 administrator
adds the account to `korinfbuilder`). The key is `buildapi/api-key` (mode 640,
group `korinfbuilder`, excluded from git; `API_KEY` in `buildapi/config` is a
fallback). There is one key for every client: changing it means updating
`~/.config/korinf-api.key` of the clients and `[korinf].api_key` of the Wine
Release Manager.

## Quick start: build a product for a system

```sh
KEY=$(cat ~/.config/korinf-api.key)
API=http://builder64.office.etersoft.ru:5503
# the systems of a product version
curl -s -H "X-API-Key: $KEY" "$API/api/product/systems?product=WINE@Etersoft&version=11-testing"
# enqueue the build: returns taskid (existing: true if the same build is queued or running)
curl -s -H "X-API-Key: $KEY" -H 'Content-Type: application/json' \
     -d '{"product": "WINE@Etersoft", "version": "11-testing", "dist": "x86_64/Ubuntu/24.04"}' \
     "$API/api/product/build"
# status, stages and output of the task
curl -s -H "X-API-Key: $KEY" "$API/api/task/<taskid>"
curl -s -H "X-API-Key: $KEY" "$API/api/task/<taskid>/progress"
curl -s -H "X-API-Key: $KEY" "$API/api/task/<taskid>/log?tail=200"
# restart a failed task
curl -s -X POST -H "X-API-Key: $KEY" "$API/api/task/<taskid>/restart"
```

The client `rebased/korinf-build.py` of
[wine-rebased-utils](https://gitlab.eterfund.ru/wine/wine-rebased-utils) does this
and waits for the result: `korinf-build.py [--force] [--check] <version> <system>`,
exit code 0 built, 1 failed, 2 still running after `KORINF_WAIT`. It reads the key
from `~/.config/korinf-api.key` (`KORINF_API_KEY_FILE`).

## Rebuild a common package

`POST /api/rebuild`, JSON:

```json
{"package": "eepm", "arch": "x86_64"}
```

`arch` defaults to `all`: the package's target `distro.list` is used (Korinf's
existing `all` behavior). An individual architecture uses `etc/lists/<arch>/build`.
Currently the builder has `x86_64` and `i586` build lists. Architectures without
a configured list are rejected. `FORCE=1` requests a rebuild and
`CLEAR_FAILED_ON_RESTART=1` clears that package's old failure markers.

The response contains `taskid` and `new_path`. Poll `/api/task/{taskid}` for
progress. `/api/build` clears the package's old failure markers by default,
including when `force` is omitted or false. Explicit `force: true` additionally
requests a forced rebuild. Use `dist` for a specific distro or another Korinf
list, e.g. `x86_64/ALL`.

## Products

The products of the system builds and personal orders are in
`robot/products.list`, one line each: the build script (`bootstrap`), whether
the build installs BuildRequires first (`init=1`), builds an i586 companion
(`i586=1`), the delivery files, URL and install script. A new product is a new
line there, not code. `GET /api/products` lists them.

## System build with stages

`POST /api/product/build`, JSON `{"product": "WINE@Etersoft", "version": "11-testing", "dist": "x86_64/ALTLinux/p10", "force": false}`
enqueues a `TASKTYPE=winebuild` task (the name stays for every product): the
robot runs the product's script, e.g.
`bin-wine/wine-etersoft-bootstrap-new.sh --nostop [--force|--init] <dist> <version>`
(robot/funcs/winebuild). `version` is a product directory with a `distro.list`,
`dist` must be one of its systems (`GET /api/product/systems?product=&version=`).
The robot builds tasks one at a time; if the same product, version and system is already
queued or building, its task is returned with `existing: true`.

The task output is in `~/sales/winebuild/<taskid>.log`
(`GET /api/task/{taskid}/log?tail=N`, web `/task/{taskid}/log`), the stages in
`<taskid>.progress`: `GET /api/task/{taskid}/progress` returns every component
(package, dist, start, duration, ok/skipped/failed, korinf steps) and the
current one. A failed component or a non-zero exit makes the task failed
(restartable). The task page shows the stages; component logs include the
i586 companion of an x86_64 system for a product with `i586=1`.

The `/api/wine/*` paths are deprecated aliases of the product ones with
`product=WINE@Etersoft`.

## Daily Sisyphus rebuilds

`tools/enqueue-sisyphus --dry-run` lists the daily plan. Without `--dry-run`,
it submits forced `TASKTYPE=winebuild` tasks to `~/sales` (or `--sales-dir`).
Products come from `robot/products.list`; versions come from each product's
published `version.list`. Historical directories absent from that list are
not scheduled. Version symlinks are resolved and deduplicated.

Every task uses `FORCE=1`, including packages whose source version has not
changed, so Sisyphus RPMs and their `.rpm.depends` are refreshed. Products with
`i586=1` build their companion within the x86_64 task; other products receive
separate x86_64 and i586 Sisyphus tasks. The scheduler may enqueue this i586
companion even when the public `distro.list` lists only x86_64.

The normal robot worker serializes all Sisyphus products, versions and
architectures using their shared system resource. No builds run in cron.
Queue publication is locked against concurrent API submissions; active tasks
and version aliases are reused. A forced request only reuses a forced task;
if a non-forced build is active, the forced build queues behind it under
the same worker resource lock. The existing task is left unchanged. `.sisyphus-daily.json` in the queue prevents
another submission on the same day, even after completion or failure.
The next day retries failed builds but does not duplicate active ones.

Install `tools/cron/enqueue-sisyphus.cron` in builder's crontab, preserving
existing entries. It queues work daily at 06:00 Europe/Moscow; execution may
start later when a worker is available. Submission output goes to
`~/.korinf-worker/sisyphus-daily.log`; build logs and statuses use the normal
queue. A malformed or missing product/version list aborts plan creation
before any tasks are submitted.

## Conservative repair and live log

Reviewed failures have a persistent comment in `buildapi/comment-state/<taskid>.json`.
`GET /api/task/{taskid}/comment` reads it; `PUT` with JSON `{"text":"..."}`
writes it (X-API-Key required). The task page also has an edit form; comments
store the review time and the build log modification time. The review time
is displayed above the comment text; the failure date is shown in the task note.
are displayed there and in the queue. Only failed/broken/removed/interrupted
tasks accept edits, up to 16000 characters. Empty text removes the comment.
A nonempty comment disables AI repair in the UI and returns HTTP 409 from
both repair POST routes, for either engine. Comments survive queue restarts
and remain visible on completed tasks. They do not cancel a running repair.

The “Починить сборку” button appears next to restart on failed task rows and
task pages. Its dropdown selects MiMo (`xmimo`, default) or Codex; the browser
remembers the selection. `POST /api/task/{taskid}/repair` accepts an optional JSON
body `{"engine":"mimo"}` or `{"engine":"codex"}`. Without a body it uses MiMo.
GET on that URL returns status, report and patch. The task page polls
`/task/{taskid}/repair/log` every 2 seconds and updates commands, output, report
and diff without reloading. Uncheck “Следить за концом лога” to read earlier
output. API clients can poll `/api/task/{taskid}/repair/log` with `X-API-Key`.
Responses are not cached and each log is bounded to its last 128 KiB.
Finished/interrupted runs keep their journal. One repair can run at a time, for up to
20 minutes. Refreshes do not start additional workers. State survives API
restarts; interrupted workers are shown as interrupted and can be retried.

MiMo is launched through `xmimo run --pure --format json`, with the most recent
model from the builder account's MiMo state (currently `xiaomi/mimo-v2.5`).
It uses the wrapper's existing shared authentication. A separate `bwrap` sandbox
mounts the host read-only and permits writes only in the disposable checkout
and that run's MiMo runtime. Extra plugins/project config and subagents are
disabled. A non-JSON MiMo answer is kept as a report and is never auto-applied.

Codex uses the builder account's existing CLI login, ignores its MCP/config
and exec rules, and runs in a workspace-write sandbox in a disposable clone.
Relevant log excerpts and failure history are provided as untrusted evidence.
It cannot edit live files from that sandbox. Only a high-confidence, checked
change to one matching `bin-*/<package>.sh` recipe (at most 80 changed lines)
can be applied by the worker, after a separate `bash -n` check. Alternatively,
the model can fix existing pkgrepl rules in `.repair-pkgrepl`, a disposable
clone of the sibling `etersoft-build-utils` repository. The worker validates
mapping syntax, duplicate keys and the change size (up to 32 files and 240 lines),
backs up the originals and applies only those mapping files. Recipe and mapping
edits in the same run require review. The live build-utils repository stays
read-only to both model runners. Existing local
edits, concurrent file/task changes and running builders prevent application.
For product tasks the candidate recipes come from the failed components.
Large or uncertain changes remain in the clone for review. There is no
automatic rebuild, publication or service restart.

State, workspaces, executor logs and the original recipe backup are in
`~/.local/state/korinf-repairs/<taskid>/<run>/`; the task page shows the latest
report and diff. `applied` means the recipe changed, not that a build succeeded.
Codex uses the installed CLI's default model.

## Component logs and theme

Task pages list the latest package logs under `/var/ftp/pub/Korinf`, the
matching product/version under `/var/ftp/{pub,pvt}/Etersoft`, and Korinf's
working log directory. Failure markers put failed components first.
`GET /api/task/{taskid}/logs` returns the index. Log URLs accept opaque IDs
from that index, never arbitrary filesystem paths. Compressed xz/bz2/gzip
logs are decoded with bounded memory; the viewer shows at most 256 KiB.
These are shared package logs, not immutable per-attempt archives; compare
their timestamp with the task's failure history.

The theme selector offers system/light/dark, saved as `korinf-theme` in
browser localStorage. System mode follows OS changes automatically.

## Validation

```sh
python3 tests/test_winebuild.py
python3 tests/test_systembuild_api.py
python3 tests/test_buildapi_features.py
python3 tests/test_repair_progress.py
python3 tests/test_buildapi_restart.py
```

The feature tests use temporary queues, repositories and fake Codex/MiMo processes;
they do not start production builds or require a paid model call.

## Personal delivery orders

The single user entry point is http://builder64.office.etersoft.ru:5502/orders.
Wine UI authenticates users with Kerberos (ETERSOFT.RU), supplies their principal
to Korinf server-side and keeps the API key out of the browser. All authenticated
employees can order their own builds; release-management permissions are separate.
POST requests in the UI require the page's session CSRF token.

API (all require X-API-Key), for every product of robot/products.list:
- GET /api/orders/versions — the versions of every product from its version.list
  (labels, default) for one choice.
- GET /api/orders/distributions?product=...&version=...&principal=... — x86_64
  targets from the version's distro.list, including systems awaiting their first build.
- GET /api/orders?principal=... — personal orders placed through this API.
- POST /api/orders — JSON principal, product, version, dist. The principal is a
  trusted gateway assertion: API-key holders must never forward a browser-supplied
  identity without authentication.

The profile is the newest completed order of the same product (a product with
`license_types=1` must name a known license type). With `downloaddir=1` the task
gets DOWNLOADDIR=<product>/<version>. The robot (products/wine-etersoft,
products/rx, products/crypto) records the delivery directory and the readiness
marker of an order; the download is the product's `download_url` (by default
https://download.etersoft.ru/pub/download/<product>/<directory>/).

The newest completed order of the product in /srv/builder/done addressed exactly to
login@etersoft.ru supplies registration and license fields. No matching order
returns 404. Task fields are reconstructed as data, never sourced by the API.
New tasks request clearing previous failures and follow normal robot email delivery.
Identical queued/running requests are deduplicated.

Private order metadata is in buildapi/order-state/<email>/, excluded from git.
The worker records WEB_DOWNLOAD_REL in the task and writes a task-specific
.order-<taskid>.ready marker after preparing files. The API requires this marker and
the product's `required` files (WINE@Etersoft: license, installer and SHA256
manifest) before returning download links.
Completed orders whose files disappeared are expired. Order history starts with
this API; legacy tasks have no reliable association with random download folders.

Checks:
python3 tests/test_wine_orders.py
python3 tests/test_buildapi_features.py
python3 tests/test_buildapi_restart.py
Wine UI: python3 webui/test_order_web.py

## Обновление epm в WINE

Web-страница — в Release Manager: http://builder64.office.etersoft.ru:5502/epm-update (публикация под Kerberos,
`allowed_users`); она вызывает тот же backend `source_updates`.  Здесь своей web-формы и пункта меню нет: у web-части
buildapi нет аутентификации.

API (оба метода требуют `X-API-Key`):

- `GET /api/source-updates/epm` — предпросмотр с выбором по умолчанию.
- `GET /api/source-updates/epm?branch=10-testing&branch=11-unstable` — явный выбор.
- `POST /api/source-updates/epm` с JSON
  `{"branches":["10-testing"],"preview_token":"<из предпросмотра этого же выбора>"}`.

POST дополнительно отклоняет запросы с чужим Origin/Referer или Sec-Fetch-Site. Изменившиеся источник или назначения
делают токен недействительным: получите новый предпросмотр и проверьте его.
Release Manager, API и `tools/update-epm` используют один backend `source_updates`; стабильные ветки и
небезопасные общие каталоги запрещаются там. Готовый SRPM копируется без
редактирования; установщик генерируется из epm, извлечённого именно из этого
SRPM, с проверкой версии и контрольной суммы источника. Генерация выполняется
и при уже опубликованном SRPM. Предпросмотр и API-результат включают объект
`installer` с путём назначения, версией epm и метаданными; результат также
содержит состояние и SHA-256 установщика. Автоматический запуск сборок
и перезапуск задач не выполняются.
