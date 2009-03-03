#!/bin/sh -x
##
#  Korinf project
#
#  Publish product for client by task file
#
#  Copyright (c) Etersoft <http://etersoft.ru> 2006, 2007, 2009
#  Copyright (c) Vitaly Lipatov <lav@etersoft.ru> 2006, 2007, 2009
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.

#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
##

# Выполняет сборку по первому заказу в списке
# Отправляет на реальный адрес только с параметром --real /путь
# Также отладку можно включить, создав файл arobot.sh.debug
# (c) Etersoft
# 08.06.2006, 09.06.06, 28.02.07, 09.03.07, 15.12.07, 2008
# FIXME: если в имени запятая, разделяет на два адреса
#
#export LANG=ru_RU.UTF-8
#export LC_ALL=ru_RU.UTF-8

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod korinf
set_log_dir /`date "+%Y%m%d"`

umask 0002

. `dirname $0`/../share/eterbuild/robot/arobot-functions.sh
. `dirname $0`/../share/eterbuild/robot/arobot-wine.sh
. `dirname $0`/../share/eterbuild/robot/arobot-selta.sh



# Path to chroot dir (remote system mounted)
#export BUILD=/net/abuild
# User in remote(build) system
#export INTUSER=arobot
# Local path to remote user home
export BUILDERHOME=/srv/arobot

# Системы для сборки (стабильная)
#export LINUXHOST=/net/os/stable
#export LINUXHOST=/net/os
# Для какой версии отгружаем

# clear version (get in TASK)
export WINENUMVERSION=
DEAR="Здравствуйте,"

REALRUN="$1"
if [ "$REALRUN" = "--real" ] ; then
	shift
fi

TASK="$1"
[ -e "$TASK" ] || { warning "Have not any tasks..." ; sleep 1 ; exit_now ; }

#test -w "$TASK" || { do_removed ; fatal "Can't touch $TASK file, check permissions" ; }
test -w "$TASK" || do_removed

# Why recode TASK if all in utf8?
cat $TASK | iconv -f utf8 -t koi8-r -r

# WARNING!!! execute file!!!
# load all vars (DIST, MAILTO, PRODUCT, ETERREGNUM, FULLNAME)
. $TASK

cat $TARGETDIR && do_removed

# TODO: ��������� TARGETDIRNAME � TASK
export TARGETDIRNAME=`basename $TARGETDIR`

[ -z "$WINENUMVERSION" ] && { do_broken "Empty WINENUMVERSION" ; }

export BASEPATH=$WINEETER_PATH/$WINENUMVERSION

# Из-за проблемы с переназначением $PRODUCT при ошибке.
PRODUCTVAR=$PRODUCT
#BUILDNAME=wine-etersoft-$PRODUCT
#unset PRODUCT

echo "Build for $TASK (on $DIST)"

[ -z "$DIST" ] && [ -e "$TASK" ] && do_removed

if [ "$REALRUN" = "--real" ] && [ ! -f $0.debug ] ; then
	FULLMAILTO="\"$FULLNAME\" <$MAILTO>"
else
	FULLMAILTO="Испытание <lav@etersoft.ru>"
fi
export FULLMAILTO
export EMAIL="Система отгрузки Etersoft <support@etersoft.ru>"


# Выходить при любой неприятности
# TODO:
#CAREBUILD=1
# TODO: изменить название. очищать каталог hasher
export NIGHTBUILD=1

#fatal "По техническим причинам отгрузка приостановлена."

# split to subscript
case $PRODUCTVAR in
	*WINE@Etersoft*)
		build_wine
		;;
	*SELTA@Etersoft*)
		build_selta
		;;
	*)
		fatal "Unknown product $PRODUCTVAR"
		;;
esac

mkdir -p "$TARGETDIR/../done/"
mv -f $TASK "$TARGETDIR/../done/" || fatal "Can't remove task"
DATE=`date`
echo "# built done at $DATE" >>$TARGETDIR/../done/`basename $TASK`
exit_now
