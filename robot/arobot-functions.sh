#!/bin/sh -x
##
#  Korinf project
#
#  Publish product functions
#
#  Copyright (c) Etersoft <http://etersoft.ru> 2006, 2007, 2009
#  Copyright (c) Vitaly Lipatov <lav@etersoft.ru> 2006, 2007, 2009
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
##

# Выполняет сборку по первому заказу в списке
# Отправляет на реальный адрес только с параметром --real /путь
# Также отладку можно включить, создав файл arobot.sh.debug
# (c) Etersoft
# 08.06.2006, 09.06.06, 28.02.07, 09.03.07, 15.12.07, 2008
# FIXME: если в имени запятая, разделяет на два адреса
#

exit_now()
{
	[ -n "$1" ] && exit $1 || exit 0
}

warning()
{
	test -n "$@" && echo "Warning: $@"
}

do_broken()
{
	mv -f $TASK $TASK.broken
	test -n "$@" && echo "FATAL: $@"
	exit 1
}

do_removed()
{
	mv -f $TASK $TASK.removed
	test -n "$@" && echo "FATAL: $@"
        exit 1
}


# TODO: вынести во внешний код
# Фамилия должна быть на первом месте
get_name()
{
    local name
    LN=`echo $1 | awk '{print $1}'`
    FN=`echo $1 | awk '{print $2}'`
    SN=`echo $1 | awk '{print $3}'`
    # Если неизвестно, к кому обращаемся
    if [ -z "$1" ] ; then
       echo "покупатель"
       return 0
    fi

    if [ `expr index  "$FN" '.'` != 0  -o `expr index  "$SN" '.'` != 0  ] ; then  # если Петров И. А. или Петров И.
	    
	name=`echo $LN $FN $SN`
	#echo $name
    else
        # FI
	if [ -z "$SN"  ] ; then 
	    name=`echo $FN`
	    #name=$2 $1
	    #echo $name	
	else
	#FIO
    	    name=`echo $FN $SN`
	    #name=$2 $3
	fi
    fi
    if [ -z "$name" ] ; then
        name=$1
    fi
    echo $name
    return 0
}

webusy()
{
# Письмо клиенту
NAME=`get_name "$FULLNAME"`
export EMAIL="Система отгрузки Etersoft <support@etersoft.ru>"
(	echo "
${DEAR} ${NAME}!

Вы заказали сборку продукта ${PRODUCTVAR} (релиз $WINENUMVERSION)
для системы ${DIST}.

К сожалению, в настоящий момент по причине подготовки
новой версии программы ваш заказ выполнить невозможно.

Ваш заказ принят и будет обработан после возобновления
работы системы отгрузки.
Повторно заказывать получение экземпляра не нужно.

Надеемся на понимание и приносим извинения за задержку.

-- 
КОМАНДА РАЗРАБОТЧИКОВ
Etersoft, 2008
" ;
) | mutt -s "Сборка ${PRODUCTVAR} задерживается" "${FULLMAILTO}" -b "support@etersoft.ru"

}

fatal()
{
	export LANG=ru_RU.UTF-8
	[ -z "$TMPMAIL" ] && TMPMAIL=/dev/null
	LOGFILE=$ALOGDIR/$DIST/$BUILDNAME.log
	[ -r "$LOGFILE" ] && PARAMMUTT="-a $LOGFILE" || PARAMMUTT=""
# Письмо в support
(	echo "
Произошла ошибка '${@}' при сборке
продукта $PRODUCTVAR (релиз $WINENUMVERSION) с номером $ETERREGNUM
для платформы $DIST. Получатель: $FULLMAILTO.
Каталог результата: $TARGETDIR.
Задание отложено до исправления проблемы.

Prepared mail in $TMPMAIL:
`cat $TMPMAIL`

-- 
Eterbuild: $Id: arobot.sh,v 1.72 2008/12/28 21:35:29 builder Exp $
" ;
[ -r "$LOGFILE" ] && echo "Лог сборки $LOGFILE приложен." || echo "Лог сборки $LOGFILE не был создан. "
) | mutt -s "Ошибка при сборке $ETERREGNUM" lav@etersoft.ru boris@etersoft.ru $PARAMMUTT

# Письмо клиенту
NAME=`get_name "$FULLNAME"`
export EMAIL="Система отгрузки Etersoft <support@etersoft.ru>"
if tail -n1 $TASK | grep -v FAILED ; then
(	echo "
${DEAR} ${NAME}!

Вы заказали сборку продукта ${PRODUCTVAR} (релиз $WINENUMVERSION)
для системы ${DIST}.

К сожалению, произошла ошибка при сборке пакета для Вас.
Служба поддержки извещена. Ваш заказ принят и будет обработан
после исправления проблемы.
Повторно заказывать получение экземпляра не нужно.
Надеемся на понимание и приносим извинения за задержку.

-- 
Команда разработчиков
Etersoft, 2008
" ;
) | mutt -s "Ошибка при сборке $ETERREGNUM" "${FULLMAILTO}" -b "support@etersoft.ru"
fi

	echo "$@" >&2
	DATE=`date`
	echo "# built FAILED at $DATE (Error: ${@})" >>$TASK
	[ -e "$TASK" ] && mv -f $TASK $TASK.failed
	exit_now 1
}


printURL()
{
	LDIR=$1
	DDIR=$2
	shift
	shift
	[ -n "$1" ] || return 1
	for i in $@ ; do
		# Размер файла в байтах
		FSIZE=`stat "--printf=%s" $LDIR/$i`
		let KSIZE=$FSIZE/1024
		[ "$KSIZE" -lt "1" ] && KSIZE=1
		printf "[ %5d Кб]  " $KSIZE
		echo $DDIR/$i
	done
	return 0
}


