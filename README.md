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

### Минимальная версия cpio для deb-сборок

Для конвертации RPM через alien нужен **cpio >= 2.15**: старые версии
неправильно извлекают симлинки (ALT #42189). Обёртка cpio не используется.
При установке зависимостей (`-i` или `--init`) выполняется
`epm --auto assure cpio cpio 2.15`. Перед конвертацией версия проверяется
повторно через dpkg, в том числе при запуске без `-i`.

При первоначальном bootstrap epm проверка выполняется через dpkg:
cpio нужной версии должен быть установлен в исходном образе заранее.
Если репозиторий системы предоставляет только старую версию (например,
Ubuntu 22.04 — 2.13), `assure` завершится ошибкой: сначала требуется
совместимый обновлённый пакет cpio в сборочном образе.

Для **сборочных образов Ubuntu 22.04 (Jammy), amd64** проверен готовый
Debian snapshot-пакет `cpio_2.15+dfsg-1_amd64.deb`:

- URL: <https://snapshot.debian.org/file/a84960d7d31ecf8dd2a02df1720b3e6adac72a0b>.
- SHA-256: `4263228674d0d32689be7e490ac6810e3536895672e562661594094f88bdc84a`.
- `Depends: libc6 (>= 2.34)`; Jammy предоставляет libc6 2.35.

Это конкретный совместимый пакет для Jammy; его нельзя автоматически
считать подходящим для других дистрибутивов. Более новый готовый пакет Ubuntu
`2.15+dfsg-1ubuntu2.1` требует libc6 >= 2.38 и для этих образов не подходит.
Исходники и содержимое пакета при установке не меняются.

Пример сохранения обновления в образ `wine-11.0`:

```bash
BOOTSTRAP=1 KORINFMODULE=wine-11.0 ./bin/korexec x86_64/Ubuntu/22.04 '
  curl -fL https://snapshot.debian.org/file/a84960d7d31ecf8dd2a02df1720b3e6adac72a0b \
    -o /tmp/cpio_2.15+dfsg-1_amd64.deb &&
  echo "4263228674d0d32689be7e490ac6810e3536895672e562661594094f88bdc84a  /tmp/cpio_2.15+dfsg-1_amd64.deb" | sha256sum -c - &&
  sudo epm --auto install /tmp/cpio_2.15+dfsg-1_amd64.deb &&
  cpio --version && echo CPIO_UPDATE_OK
'
```

Для `wine-11.12` замените `KORINFMODULE`; для 32-битной сборки укажите
`Ubuntu/22.04` вместо `x86_64/Ubuntu/22.04`. Проверенные 32-битные сборочные
окружения тоже используют amd64 как основную архитектуру и i386 как дополнительную,
поэтому в них устанавливается этот же amd64-пакет.

`korexec` может вернуть нулевой код после сбоя вложенной команды: проверьте
маркер `CPIO_UPDATE_OK`, затем сохранённую версию отдельным запуском без bootstrap:

```bash
KORINFMODULE=wine-11.0 ./bin/korexec x86_64/Ubuntu/22.04 \
  'dpkg-query -W cpio; cpio --version'
```

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
curl -X POST http://builder64.office.etersoft.ru:5503/api/build \
  -H "X-API-Key: $KEY" -H "Content-Type: application/json" \
  -d '{"package":"eepm","dist":"x86_64/ALTLinux"}'
```

**Поведение:** успех → `~/done/<base>.done`; провал → `<base>.task.failed` с маркером `# build FAILED at ... (Error: korinf <пакет> <система> exit N)` (перезапускается через `tools/arobot-retouch.sh` или buildapi `POST /api/task/{id}/restart`). Состояние видно в buildapi (веб `/` и `/api/tasks`), пакет группируется по имени.

### Типичные ошибки Robot

- `Package wine-etersoft should be rebuilt` - основной пакет не собран
- `Can't rebuild wine-etersoft-winetricks component` - провал компонента
- `Permission denied` - проблемы с правами NFS

### korinf/install - BuildRequires для wine

#### Почему `-i` мог оставлять неполное окружение

При проверке сборок 8–9 октября 2026 выявлены следующие причины:

- В AstraLinuxSE ненулевой результат установки зависимостей игнорировался.
  Скрипты настройки пакетов пытались запускать службы в контейнере без systemd,
  `dpkg` оставался с ненастроенными пакетами, но этап `-i` считался успешным.
  Теперь перед установкой выполняется `prepare-astra-container`, а ошибка
  установки зависимостей останавливает этап.
- `--skip-installed` проверяет наличие пакета, но не обновляет его. Поэтому
  установленный комплект `ia32-libs` 2021 года не заменялся новым комплектом,
  содержащим необходимые 32-битные библиотеки, в частности FreeType.
  Теперь `-i` устанавливает зависимости без `--skip-installed`, позволяя
  менеджеру пакетов обновить запрошенные зависимости, в том числе `ia32-libs`.
  Полный upgrade системы не требуется. Проверенный EPM на Astra вызывает
  `apt-get dist-upgrade` даже при указании имён пакетов в `epm upgrade`.
- Наличие библиотек не гарантирует, что компилятор их найдёт: в Astra они
  находятся в `/usr/lib32/i386-linux-gnu` и `/lib32/i386-linux-gnu`.
  Подготовка контейнера добавляет эти пути только для GCC с `-m32`.
- Создание временных bootstrap-зависимостей через EPM зависело от версии
  `create-fake` и возможности перепаковать пустой RPM. Для Debian-систем
  теперь создаётся и устанавливается пустой deb штатными `dpkg-deb`/`dpkg`.
- В Uncom установка зависимостей завершалась ошибкой загрузки репозитория.
  `-i` не может установить отсутствующие пакеты, пока репозиторий недоступен.
  На 9 октября `repository.uncom.tech` отвечал HTTP 503; рабочее зеркало
  необходимо проверить перед изменением настроек.

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
