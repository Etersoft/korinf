# Обновление epm в testing/unstable WINE

`tools/update-epm` выбирает новейший готовый исходный пакет **eepm** из
`/var/ftp/pub/Korinf/sources` по RPM epoch/version/release. Пакеты eepm-apt,
eepm-yum и другие подпакеты не выбираются.

```sh
# Только просмотр. По умолчанию текущие ветки 10 и 11 testing/unstable.
./tools/update-epm
# Явный выбор веток, просмотр в JSON.
./tools/update-epm 11-testing 11-unstable --json
# Копирование в явно выбранные ветки.
./tools/update-epm 11-testing 11-unstable --apply
```

Назначение: `/var/ftp/pub/Etersoft/WINE@Etersoft/ВЕТКА/sources`.
Содержимое SRPM не изменяется, SHA256 скопированного файла проверяется.
Старые исходники сохраняются; бинарные пакеты и индексы команда не трогает.
Следующая штатная сборка eepm подхватит новый исходник. Уже начатые сборки
не перезапускаются. Для выполнения нужны права записи в каталоги назначения.

Разрешены только ветки `testing`, `unstable` и имена с суффиксом `-testing`
или `-unstable`. Стабильные ветки запрещены также через симлинки и общий
каталог sources. Служебный `last`, если он ссылается на development-ветку,
считается плавающим алиасом, а не стабильным релизом.

Предварительная проверка отклоняет понижение версии и конфликт содержимого
одинаковых имён. Наличие выбранного старого SRPM в ветке не разрешает
обновление installer, если рядом уже опубликован более новый SRPM. Повторная публикация идентичного RPM возвращает `unchanged`.
Копирование публикует полный файл атомарно, без перезаписи существующего.
Все выбранные ветки проверяются до начала копирования; ошибки файловой системы
при выполнении возвращаются отдельно для каждой ветки (общей транзакции NFS нет).

Web: Release Manager, http://builder64.office.etersoft.ru:5502/epm-update (Kerberos):
выберите ветки, обновите предпросмотр и нажмите «Обновить epm и установщик».
Изменение исходника, назначения или выбранных веток требует нового просмотра.
API GET/POST `/api/source-updates/epm` buildapi использует `X-API-Key`.
Lock `buildapi/source-update.lock` должен быть доступен на запись группе
winebuilder (Release Manager работает от builder-robot).

Тесты: `python3 -B -m unittest discover -s tests -p 'test_source_updates*.py'`.

При применении также собирается `docs/wine-etersoft-install.sh` в приватном
`/var/ftp/pvt/Etersoft/WINE@Etersoft/ВЕТКА`. Штатный `make_wine_part.sh` получает
точную временную копию выбранного SRPM и имя ветки для выбора winetricks;
он сам извлекает eepm и выполняет `pack_in_onefile.sh`. Локальный eepm HEAD
не используется. Проверяются SHA256 исходника и генератора, соответствие
`EPMVERSION` версии RPM и синтаксис результата через `bash -n`.

Рядом с установщиком лежат `eget-winetricks.db` и `eget-winetricks.db.manifest`
(как в `shipment-to-sales.sh`): `--cache` установщика загружает компоненты через
эту базу IPFS. Публикация epm требует базу для текущего пакета
wine-etersoft-winetricks ветки (manifest), иначе отказывает. База обновляется
отдельно, это может идти долго (загрузка компонентов и `ipfs add` через
`EGET_IPFS_API`):

```sh
./tools/update-epm --ipfs-db 11-testing
```

`make-winetricks-ipfs-db.sh ... all` начинает от опубликованной базы: для того же
пакета winetricks генерация пропускается, иначе обновляются изменившиеся URL.
База и manifest заменяются атомарно (manifest последним), как установщик.
Рабочие каталоги генерации удаляются.

Генератор хранится как **экспорт**, не git clone, в
`/srv/builder/Projects/wine-base-bottle-scripts`. Другой путь задаётся через
`KORINF_INSTALLER_SNAPSHOT`. `SNAPSHOT.json` содержит upstream commit и SHA256
неизменённых файлов. Текущий проверенный экспорт:
`580a187728427b2330c65d462fa4b88905bd0e20` из
`https://gitlab.eterfund.ru/wine/wine-base-bottle-scripts`.

Все выбранные installer собираются до первой публикации. Параллельные apply
защищены flock. Ошибка генерации не публикует ни одного SRPM. Установщик
публикуется заменой записи каталога (`os.replace`), поэтому существующий
hardlink на stable остаётся неизменным. Общие со stable каталоги docs и
симлинки installer запрещены. Если публикация installer завершается ошибкой,
созданный этой операцией SRPM удаляется обратно; ошибка отката отражается
отдельно. При уже опубликованном SRPM installer всё равно проверяется и
обновляется. Проверка версии и генерация не запускают сам installer.

Временные каталоги `korinf-installer-*` сохраняют результат, `build.log` и
`provenance.json`: источник/его SHA256, commit генератора, hashes файлов,
ветку, версию и SHA256 результата. Helper `buildapi/epm_installer.py`
сам ничего на FTP не публикует. Дополнительные тесты:
`python3 -B -m unittest discover -s tests -p 'test_epm_installer.py'`.
