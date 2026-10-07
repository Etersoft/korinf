# Korinf web and API

Open `/docs` for the interactive API documentation. `/api/*` requires the
`X-API-Key` header (configured in `buildapi/config`). The web interface uses
the existing internal-network access model, without individual accounts.

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

## WINE@Etersoft system build with stages

`POST /api/wine/build`, JSON `{"version": "11-testing", "dist": "x86_64/ALTLinux/p10", "force": false}`
enqueues a `TASKTYPE=winebuild` task: the robot runs
`bin-wine/wine-etersoft-bootstrap-new.sh --nostop [--force] <dist> <version>`
(robot/funcs/winebuild). `version` is a WINE@Etersoft directory with a
`distro.list`, `dist` must be one of its systems (`GET /api/wine/systems?version=`).
The robot builds tasks one at a time; if the same version and system is already
queued or building, its task is returned with `existing: true`.

The task output is in `~/sales/winebuild/<taskid>.log`
(`GET /api/task/{taskid}/log?tail=N`, web `/task/{taskid}/log`), the stages in
`<taskid>.progress`: `GET /api/task/{taskid}/progress` returns every component
(package, dist, start, duration, ok/skipped/failed, korinf steps) and the
current one. A failed component or a non-zero exit makes the task failed
(restartable). The task page shows the stages; component logs include the
i586 companion of an x86_64 system.

## Conservative repair and live log

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
can be applied by the worker, after a separate `bash -n` check. Existing local
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
python3 tests/test_winebuild_api.py
python3 tests/test_buildapi_features.py
python3 tests/test_repair_progress.py
python3 tests/test_buildapi_restart.py
```

The feature tests use temporary queues, repositories and fake Codex/MiMo processes;
they do not start production builds or require a paid model call.

## Personal Wine delivery orders

The single user entry point is http://builder64.office.etersoft.ru:5502/orders.
Wine UI authenticates users with Kerberos (ETERSOFT.RU), supplies their principal
to Korinf server-side and keeps the API key out of the browser. All authenticated
employees can order their own builds; release-management permissions are separate.
POST requests in the UI require the page's session CSRF token.

API (all require X-API-Key):
- GET /api/wine/versions — labels/default from the FTP version.list.
- GET /api/wine/distributions?version=...&principal=... — x86_64 targets from the version's distro.list, including systems awaiting
  their first build, for the user's product.
- GET /api/wine/orders?principal=... — personal orders placed through this API.
- POST /api/wine/orders — JSON principal, version, dist. The principal is a
  trusted gateway assertion: API-key holders must never forward a browser-supplied
  identity without authentication.

The newest completed Wine order in /srv/builder/done addressed exactly to
login@etersoft.ru supplies registration and license fields. No matching order
returns 404. Task fields are reconstructed as data, never sourced by the API.
New tasks request clearing previous failures and follow normal robot email delivery.
Identical queued/running requests are deduplicated.

Private order metadata is in buildapi/order-state/<email>/, excluded from git.
The worker records WEB_DOWNLOAD_REL in the task and writes a task-specific
.order-<taskid>.ready marker after preparing files. The API requires this marker,
license, installer and SHA256 manifest before returning download links.
Completed orders whose files disappeared are expired. Order history starts with
this API; legacy tasks have no reliable association with random download folders.

Checks:
python3 tests/test_wine_orders.py
python3 tests/test_buildapi_features.py
python3 tests/test_buildapi_restart.py
Wine UI: python3 webui/test_order_web.py
