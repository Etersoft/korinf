#!/bin/sh
# -------------------------------------
# $Id$
# -------------------------------------
# Скрипт удаляющий устаревшие ссылки 
# сгенерированные для скачивания файлов
#---------------------------------------

remove_old()
{
# Базовый каталог, где создаются ссылки
DOWNDIR="$1"
DEP="$2"

# Время устаревания, в минутах
#MINAGO=30
#[ -n "$1" ] && MINAGO=$1
#find ${DOWNDIR} -type l -and -cmin +${MINAGO} | xargs rm -f

# Время устаревания, в днях
DAYSAGO=5

test -d ${DOWNDIR} || exit 1
#find ${DOWNDIR} -type f -and -mtime +${DAYSAGO} | grep -v done | xargs rm -f
#find ${DOWNDIR} -type l -and -mtime +${DAYSAGO} | xargs rm -f
# каталог с названием 'done' исключаем!
find ${DOWNDIR} -mindepth $DEP -maxdepth $DEP -type d -and -mtime +${DAYSAGO}  | grep -v done | xargs rm -rf
find ${DOWNDIR} -type f -name "*.lic" -mtime +${DAYSAGO}  | grep -v done | xargs rm -f

# прежде чем удалить пустые каталоги делаем паузу 
# (на случай если он только, что создан, но файлы ещё не успели туда положить)
MPAUSE=1

sleep $(($MPAUSE*70))

find ${DOWNDIR} -type d -and -cmin +$MPAUSE | grep -v done | xargs rmdir -p 2>/dev/null
}

#echo "Disable autoclean: needs rewrite to check directory date"
#
remove_old /var/ftp/pub/download/WINE@Etersoft 4
remove_old /var/ftp/pub/download/SELTA@Etersoft 2
#remove_old ./1
