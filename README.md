# Korinf - Система сборки пакетов

## Быстрый старт

**Проверить статус:**
```bash
cd ~/Projects/korinf/bin-wine
./wine-etersoft.sh Ubuntu/14.04 2.1 -c
```

**Пересобрать пакет:**
```bash
./wine-etersoft.sh Ubuntu/14.04 2.1 -f
```

**Собрать все компоненты:**
```bash
./wine-etersoft-bootstrap-new.sh Ubuntu/14.04 2.1
```

**Посмотреть провалившиеся задачи robot:**
```bash
ls -t ~/sales/*.failed | head -10
```

---

## Основная информация

- Рабочий каталог: `~/Projects/korinf` на машине `builder@builder`
- Все действия через: `ssh builder@builder`
- Логи сборки: `~/Projects/korinf/log/`
- Просмотр логов: `ercat file.log`
- Задания robot: `~/sales/`

## Параметры скриптов сборки

### Обычные скрипты (wine-etersoft.sh, wine-etersoft-local.sh и т.д.)

| Параметр | Описание |
|----------|----------|
| `-c` | Проверить статус |
| `-f` | Пересобрать провалившиеся |
| `-F` | Пересобрать все |
| `-i` | Установить зависимости |
| `-b` | Собрать и установить |

### Bootstrap скрипт (wine-etersoft-bootstrap-new.sh)

| Параметр | Описание |
|----------|----------|
| `--check` | Показать статус всех компонентов |
| `--init` | Собрать с установкой зависимостей |
| `--force` | Принудительная пересборка всех |

### Статусы сборки

- **MIS** - пакет не собран
- **OBS** - устаревшая сборка
- **ABF** - автосборка провалилась
- **FIL** - ручная сборка провалилась

## Система задач Robot (~/sales)

**Типы файлов:**
- `.task` - активное задание
- `.task.failed` - провалившееся задание

**Посмотреть ошибки:**
```bash
ls -t ~/sales/*.failed | head -5
cat ~/sales/имя_файла.task.failed
```

**Перезапуск после исправления:**
```bash
# 1. Исправить проблему вручную
./wine-etersoft.sh x86_64/Ubuntu/24.04 10.10 -f

# 2. Переименовать файл
mv файл.task.failed файл.task
```

**Массовый перезапуск для системы:**
```bash
~/Projects/korinf/tools/arobot-retouch.sh x86_64/Ubuntu/24.04
```

## Подмена зависимостей (pkgrepl)

Файлы в `/srv/builder/Projects/etersoft-build-utils/share/eterbuild/pkgrepl/`

Формат: `старое_имя|новое_имя`

Правила наследуются (например, `pkgrepl.ubuntu.14.04` ← `pkgrepl.ubuntu` ← `pkgrepl.deb`).

**Пример:** `pkgrepl.ubuntu.14.04`
```
libcrypto3|libssl1.0.0
libjpeg-devel|libjpeg8-dev
```

## Переменные окружения

Из старой документации (могут быть устаревшими):

| Переменная | Описание |
|------------|----------|
| `ADEBUG=1` | Дополнительный отладочный вывод |
| `WITHOUTEBU=1` | Сборка без etersoft-build-utils |
| `BOOTSTRAP=1` | Установить собранные пакеты |
| `NIGHTBUILD=1` | Остановка при ошибках |
| `CHECKPACKAGE=1` | Проверить статус вместо сборки |
| `REBUILDPACKAGE=1` | Принудительная пересборка |
| `INSTALLREQUIREDPACKAGE=1` | Установить зависимости |
| `REBUILDLIST` | Список целевых систем |

## Проблемы и решения

### NFS права доступа

`/var/ftp/pvt` и `/var/ftp/pub` монтируются через NFS с `ftpserver`.

**Проблема:** Permission denied при записи

**Решение:** Каталоги должны принадлежать `builder`, а не `lav`

### Отсутствующие зависимости

**Пример:** `E: Unable to locate package libcrypto3`

**Решение:** Добавить подмену в соответствующий pkgrepl файл

### Hasher не видит зависимости (ALT Sisyphus)

**Проблема:** `E: Couldn't find package libwine-etersoft-devel`

**Решение:** Обновить APT индексы через `genbasedir` или пакет устарел для Sisyphus

---

## Детальная документация

### Формат команды сборки

```bash
./скрипт.sh СИСТЕМА ВЕРСИЯ [параметры]
```

Примеры:
- `./wine-etersoft.sh Ubuntu/14.04 2.1 -c` - проверить
- `./wine-etersoft.sh Ubuntu/14.04 2.1 -i -f` - собрать с зависимостями
- `./wine-etersoft.sh -c all 2.1` - проверить все дистрибутивы

### Полный список параметров обычных скриптов

- `-q` - Тихий режим
- `-c` - Проверить статус пакета
- `-b` - Собрать и установить
- `-B` - Собрать и установить с принудительной пересборкой
- `-f` - Пересобрать провалившиеся
- `-F` - Пересобрать все пакеты
- `-i` - Установить зависимости перед сборкой
- `-I` - Принудительная установка зависимостей
- `-r` / `-R` - Проверить зависимости

### Bootstrap скрипт - что собирает

**Для wine 1.x / 2.x:**
1. Bootstrap: wine-etersoft
2. Build: wine-etersoft-local, wine-etersoft-network, wine-etersoft-sql

**Для wine 7.x / 8.x / 9.x / 10.x (x86_64):**
1. Bootstrap: eepm, wine-etersoft-gecko, wine-etersoft-mono, wine-etersoft-winetricks, wine-etersoft
2. Build: wine-etersoft-local, wine-etersoft-network, wine-etersoft-grdwine
3. Затем для i586: те же компоненты + wine32-etersoft, wine32-etersoft-grdwine

### Формат .task файла (Robot)

```bash
PRODUCT="WINE@Etersoft (лицензия на 1 рабочее место)"
COMPONENTNAME="WINE@Etersoft Enterprise"
ETERREGNUM="9C1A-7B31"               # Регистрационный номер
DIST="x86_64/Ubuntu/24.04"           # Дистрибутив
DOWNLOADDIR="WINE@Etersoft/10.10"    # Каталог загрузки
MAILTO="client@example.com"          # Email клиента
FULLNAME='Иванов Иван'              # ФИО
PROJECTVERSION="10.10"               # Версия wine-etersoft
TYPE_LICENSE=Corporate               # Тип лицензии
COUNT_LICENSE=1                      # Количество мест
DATE_START='25/11/2025'             # Дата начала
DATE_END='21/11/2040'               # Дата окончания
```

**Ошибка в .failed:**
```bash
# build FAILED at Чт 25 дек 2025 12:53:48 MSK (Error: описание ошибки)
```

### Сборка произвольного пакета (PACKAGE=)

Задача с полем `PACKAGE=` — это не торговый заказ, а запрос на **сборку пакета с произвольным именем** (`eepm`, `lavtomate-mcp`, …) под заказанную систему или список. Робот собирает его через `bin/korinf`, без лицензии и без e-mail. Маркер такого задания — непустое `PACKAGE=` (у торговых задач его нет).

```bash
PACKAGE=eepm                      # имя пакета (или package.spec)
DIST=x86_64/ALTLinux              # система или список (см. ниже)
# необязательно:
# TARGETDIR=/var/ftp/pub/Korinf    # куда складывать (по умолчанию $BUILDFARMDIR)
# FORCE=1                          # принудительно пересобрать все (-F); иначе -f
# TASKTYPE=build                   # явный маркер (необязателен)
```

`PACKAGE` — только `A-Za-z0-9._+-`, без ведущего `-` (иначе `bin/korinf` воспримет его как опцию). `TARGETDIR` — абсолютный путь **без пробелов** (пробелы ломают разбор аргументов в `bin/korinf`).

**`DIST` — система или список** (раскрывается через `set_rebuildlist` → `etc/lists/`):

| Значение | Что собирает |
|----------|--------------|
| `all` | все системы из `distro.list`/`lists/ALL` |
| `ALL` | все из `etc/lists/ALL` |
| `x86_64/ALL` | все x86_64 |
| `x86_64/build` | подборка `etc/lists/x86_64/build` |
| `x86_64/ALTLinux` | все версии ALTLinux x86_64 (`etc/lists/x86_64/ALTLinux`) |
| `x86_64/Ubuntu/24.04` | конкретный таргет |

**Создать задачу:**
```bash
# утилитой
./tools/build-task new eepm x86_64/ALTLinux
./tools/build-task new lavtomate-mcp all --force
./tools/build-task list

# или через API (нужен X-API-Key из buildapi/config)
curl -X POST http://builder:8080/api/build \
  -H "X-API-Key: $KEY" -H "Content-Type: application/json" \
  -d '{"package":"eepm","dist":"x86_64/ALTLinux"}'
```

**Поведение:** успех → `~/done/<base>.done`; провал → `<base>.task.failed` с маркером `# build FAILED at ... (Error: korinf <пакет> <система> exit N)` (перезапускается через `tools/arobot-retouch.sh` или buildapi `POST /api/task/{id}/restart`). Состояние видно в buildapi (веб `/` и `/api/tasks`), пакет группируется по имени.

### Типичные ошибки Robot

- `Package wine-etersoft should be rebuilt` - основной пакет не собран
- `Can't rebuild wine-etersoft-winetricks component` - провал компонента
- `Permission denied` - проблемы с правами NFS

### korinf/install - BuildRequires для wine

Файл: `/srv/builder/Projects/korinf/share/eterbuild/korinf/install`

```bash
if rhas "$BUILDNAME" "wine" && ! rhas "$BUILDNAME" "local" && ! rhas "$BUILDNAME" "network" ; then
    buildsystempkgs="$buildsystempkgs clang llvm lld"
fi
```

**Важно:** clang/llvm/lld **не добавляются** для wine-etersoft-local и wine-etersoft-network (старые дистрибутивы не имеют этих пакетов).

### Полезные команды

```bash
# Проверить статус всех компонентов всех дистрибутивов
./wine-etersoft-local.sh -c all 2.1

# Посмотреть лог ошибки
ercat ~/Projects/korinf/log/Ubuntu/14.04/wine-etersoft-local.log | tail -100

# Посмотреть лог установки зависимостей
ercat ~/Projects/korinf/log/Ubuntu/14.04/wine-etersoft-local.install.log | tail -100

# Принудительная пересборка всех компонентов
./wine-etersoft-bootstrap-new.sh --force Ubuntu/14.04 2.1

# Найти задания Robot по email клиента
grep -l "client@example.com" ~/sales/*.task*

# Найти задания для дистрибутива
grep -l 'DIST="x86_64/Ubuntu/24.04"' ~/sales/*.task*

# Статистика провалившихся заданий
ls ~/sales/*.failed | wc -l

# Группировка ошибок
grep "build FAILED" ~/sales/*.failed | cut -d'(' -f2 | cut -d')' -f1 | sort | uniq -c
```

### Остановка Robot

```bash
# Остановить обработку заданий
touch ~/sales/STOP

# Возобновить
rm ~/sales/STOP
```
