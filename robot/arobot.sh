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

AROBOTDIR=`dirname $0`
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod korinf
set_log_dir /`date "+%Y%m%d"`

umask 0002

. $AROBOTDIR/funcs/common
. $AROBOTDIR/funcs/license
. $AROBOTDIR/funcs/task
. $AROBOTDIR/funcs/etersoft
. $AROBOTDIR/funcs/mail
. $AROBOTDIR/products/wine-compat
. $AROBOTDIR/products/wine-etersoft
. $AROBOTDIR/products/selta


# Local path to remote user home
export BUILDERHOME=/srv/arobot

DEAR="Здравствуйте,"


REALRUN="$1"
if [ "$REALRUN" = "--real" ] ; then
	shift
fi

load_task "$1"

if [ "$REALRUN" = "--real" ] && [ ! -f $0.debug ] ; then
	FULLMAILTO="\"$FULLNAME\" <$MAILTO>"
else
	FULLMAILTO="Испытание <lav@etersoft.ru>"
fi
export FULLMAILTO
export EMAIL="Система отгрузки Etersoft <support@etersoft.ru>"

export NIGHTBUILD=1

# Run product specific function
# It can used:
# * variables from the task
# * TARGETDIRNAME - dir to place files (TODO: remove it)
# split to subscript
case $PRODUCT in
	*WINE@Etersoft*)
		# Compat
		if [ "$WINENUMVERSION" = "1.0.8" ] || [ "$WINENUMVERSION" = "1.0.9" ] ; then
			build_wine
		else
			build_wine_etersoft
		fi
		;;
	*SELTA@Etersoft*)
		build_selta
		;;
	*)
		fatal "Unsupported product $PRODUCT"
		;;
esac

mkdir -p "$TARGETDIR/../done/"
mv -f $TASK "$TARGETDIR/../done/" || fatal "Can't remove task"
DATE=`date`
echo "# built done at $DATE" >>$TARGETDIR/../done/`basename $TASK`
exit_now
