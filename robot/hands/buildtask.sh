#!/bin/sh -x
##
#  Korinf project
#
#  Publish product for client by task file
#
#  Copyright (c) Etersoft <http://etersoft.ru> 2006, 2007, 2009, 2010
#  Copyright (c) Vitaly Lipatov <lav@etersoft.ru> 2006, 2007, 2009, 2010
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

AROBOTDIR=`dirname $0`/..
# load common functions, compatible with local and installed script
TOPDIR=../../
. $AROBOTDIR/../share/eterbuild/korinf/common
. $AROBOTDIR/../share/eterbuild/korinf/taskfield

kormod messages/fio

set_log_dir
# /`date "+%Y%m%d"`

umask 0002

. $AROBOTDIR/funcs/common
. $AROBOTDIR/funcs/message
. $AROBOTDIR/funcs/license
. $AROBOTDIR/funcs/task
. $AROBOTDIR/funcs/etersoft
. $AROBOTDIR/funcs/mail
. $AROBOTDIR/funcs/build
. $AROBOTDIR/funcs/genericbuild
. $AROBOTDIR/funcs/winebuild


# Local path to remote user home
export BUILDERHOME=${KORINF_TASK_WORKDIR:-/srv/arobot}
mkdir -p "$BUILDERHOME" || exit 1

DEAR="Здравствуйте,"


if [ "$1" = "--check-ready" ] ; then
	export KORINF_CHECK_ONLY=1
	# Status readers normally create the log directory; a probe must not.
	set_destlogdir() { DESTLOGDIR=$DESTDIR/log; }
	shift
fi

REALRUN="$1"
if [ "$REALRUN" = "--real" ] ; then
	shift
fi

if [ "$REALRUN" = "--debug" ] ; then
	shift
	DEBUG=1
fi

# WINE@Etersoft build of one system for a project version (TASKTYPE=winebuild):
# bin-wine/wine-etersoft-bootstrap-new.sh with stage progress, no license/email.
if grep -qE '^[[:space:]]*TASKTYPE=["'"'"']?winebuild' "$1" 2>/dev/null ; then
	[ -z "$KORINF_CHECK_ONLY$KORINF_READY_ONLY" ] || task_defer
	run_wine_build_task "$1"
	exit $?
fi

# Generic package build task (PACKAGE=...): build an arbitrary package via bin/korinf
# for the requested system/list. Build-only, no license/email. Handled before load_task,
# which requires PROJECTVERSION and sources the whole task file.
if grep -qE '^[[:space:]]*PACKAGE=' "$1" 2>/dev/null ; then
	[ -z "$KORINF_CHECK_ONLY$KORINF_READY_ONLY" ] || task_defer
	run_generic_build_task "$1"
	exit $?
fi

# Fast-slot execution first checks readiness without changing the order.
# Only the audited product handlers below support this mode.
if [ -n "$KORINF_READY_ONLY$KORINF_CHECK_ONLY" ] ; then
	case "$(get_field "$1" COMPONENTNAME)" in
		*WINE@Etersoft*|*RX@Etersoft*|*CRYPTO@Etersoft*) ;;
		*) task_defer ;;
	esac
fi
if [ -n "$KORINF_READY_ONLY" ] && [ -z "$KORINF_CHECK_ONLY" ] ; then
	KORINF_READY_ONLY= "$0" --check-ready "$1" || task_defer
	export KORINF_NO_BUILD=1
fi

load_task "$1"

if [ -n "$DEBUG" ] ; then
	echo "Debug try to build $TASK for $PRODUCT"
	#exit
fi

PWGEN=`pwgen 10 1`
[ -n "$PWGEN" ] || fatal "Can't get pwgen output"
TARGETDIRNAME=${ETERREGNUM/-*/}-$PWGEN

FIOMAIL="$(get_fio_for_email "$FULLNAME" "")"
FULLMAILTO="\"$FIOMAIL\" "
[ -z "$FIOMAIL" ] && FULLMAILTO=""
if [ "$REALRUN" = "--real" ] && [ ! -f $0.debug ] ; then
	FULLMAILTO="$FULLMAILTO<$MAILTO>"
else
	FULLMAILTO="$FULLMAILTO<$USER@etersoft.ru>"
fi

export FULLMAILTO
export EMAIL="Система отгрузки Etersoft <support@etersoft.ru>"

export NIGHTBUILD=1

. $AROBOTDIR/products/common

# Run product specific function
# It can used:
# * variables from the task
# * TARGETDIRNAME - dir to place files
# split to subscript

case $COMPONENTNAME in
	*WINE@Etersoft*)
		. $AROBOTDIR/products/wine-etersoft
		build_wine_etersoft
		;;
	*SELTA@Etersoft*)
		. $AROBOTDIR/products/selta
		build_selta
		;;
	*RX@Etersoft*)
		. $AROBOTDIR/products/component
		. $AROBOTDIR/products/rx
		build_rx
		;;
	*CRYPTO@Etersoft*)
		. $AROBOTDIR/products/component
		. $AROBOTDIR/products/crypto
		build_crypto
		;;
	*)
		. $AROBOTDIR/products/component
		build_anycomponent
		#fatal "Unsupported component $COMPONENTNAME for product $PRODUCT"
		;;
esac

task_require_ready
[ -z "$KORINF_CHECK_ONLY" ] || exit 0

DONEDIR=$TARGETDIR/../done/
[ -d "$DONEDIR" ] || DONEDIR=~/done
mkdir -p "$DONEDIR"
DATE=`date`
echo >>$TASK
echo "# task done at $DATE" >>$TASK
TASKDONE="$DONEDIR/$(basename $TASK .task).done"
mv -f "$TASK" "$TASKDONE" || fatal "Can't remove task"
