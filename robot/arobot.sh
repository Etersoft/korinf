#!/bin/sh -x
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

kormod helpers
set_log_dir /`date "+%Y%m%d"`

umask 0002

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


# Path to chroot dir (remote system mounted)
#export BUILD=/net/abuild
# User in remote(build) system
#export INTUSER=arobot
# Local path to remote user home
export BUILDERHOME=/srv/arobot

# Системы для сборки (стабильная)
export LINUXHOST=/net/os/stable
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

build_pre()
{
	type=`echo $TYPE | tr A-Z a-z`
	export ETERREGNUM
	export FTPDIR=$TARGETDIR/$TYPE-$WINENUMVERSION
	# Можем стирать только каталог дистрибутива, а не весь
	test -d $FTPDIR/$DIST && rm -rf $FTPDIR/$DIST || mkdir -p $FTPDIR/ || fatal ""
	echo >> $ALOGDIR/autobuild.report.log
	echo "Build $TYPE for $ETERREGNUM in $DIST" >> $ALOGDIR/autobuild.report.log
	#link_wine_etersoft $type
	# Вывод скрипта не записывается в лог
	export BUILDSTRAP=
	# ���� �������� ����. ������

	export BUILDNAME=wine-etersoft-$type$licensetype
	build_rpm $BUILDNAME || fatal "Build failed"

	EFILE=$(ls -1 $FTPDIR/$DIST/$BUILDNAME[-_][0-9]* | head -n1)
	# Каталог уже создаётся сборкой пакета
	FTPDIR=$FTPDIR/$DIST
	#cd $FTPDIR && { md5sum *.* >MD5SUM ; cd - ; }
	# вставить номер в readme и в каталог
	DOCS=$WINEETER_PATH/$WINENUMVERSION/docs
	sed -e "s/XXXX-XXXX/$ETERREGNUM/g" <$DOCS/README_$TYPE.html >$FTPDIR/README.html || fatal "readme copying"
	sed -e "s/XXXX-XXXX/$ETERREGNUM/g" <$DOCS/license_$type$licensetype.html >$FTPDIR/license.html || fatal "license copying"
	cp -f $DOCS/${type}_manual.html $FTPDIR/manual.html || fatal "manual copying"
}


# FIXME: наладить устройство ссылок на local
# И суметь делать delta
build_local()
{
	TYPE=Local
	build_pre
}

build_network()
{
	TYPE=Network
	build_pre
}

build_networklite()
{
	TYPE=Network
	licensetype=lite
	build_pre
}

build_sql()
{
	TYPE=SQL
	build_pre
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

# Ошибка: не ловятся ошибки отсюда
prepareMail()
{
	local FILETO BETA
	FILETO=$1
	>$FILETO
	NAME=`get_name "$FULLNAME"`
	BETA=""
	# FIXME: is it used?
	if [ "$RELEASECANDIDAT" = "1" ] ; then
		BETA="
!! This is release candidat build, use it with caution !!

"
	fi

CIFSTEXT=""
if [ "$TYPE" != "Local" ] ; then
CIFSTEXT="
Для обеспечения взаимодействия по протоколу CIFS с сервером
SAMBA - пакет с модулем ядра Linux CIFS:
	$PUBDOWNLOAD1CIFS
"
fi

	cat >>$FILETO <<EOF
${DEAR} ${NAME}!

Ваш заказ по сборке Продукта ${PRODUCTVAR} (релиз $WINENUMVERSION)
для системы ${TEXTDIST} выполнен.
${BETA}
Регистрационный номер Продукта: ${ETERREGNUM}.

Для получения Продукта необходимо скачать файлы по приведённым ссылкам, в их числе:
 - документацию (файл manual.html)
 - пакет закрытой части Продукта (wine-etersoft);
 - пакеты свободной части (libwine, wine);
 - пакет haspd с драйверами аппаратных ключей защиты
HASP 4/HL, Smartkey 3 Eutron и SafeNet Sentinel;
 - пакет со свободными шрифтами Liberation (fonts-tts-liberation).

$CIFSTEXT

Для полного соответствия шрифтов в программах
рекомендуется скачать и установить пакет fonts-ttf-ms,
содержащий шрифты MS Core Fonts:
	$PUBDOWNLOAD1FONTS

-> Ссылки для скачивания файлов вашего экземпляра Продукта:
EOF
	printURL $FTPDIR $DOWNLOADDIR/$TYPE-$WINENUMVERSION/$DIST `( cd $FTPDIR ; find -L ./ -maxdepth 1 -type f | sed -e "s|\./||g" )` >>$FILETO || fatal "Error with private part (files are missed) "

	cat >>$FILETO <<EOF
(действительны в течение 4 суток)

-> Ссылки для скачивания свободной части (LGPL) Продукта:

Россия:
EOF
	LOCALFILES=`( cd $PUBLOCAL ; find -L WINE/$DIST -maxdepth 1 -type f ; find -L fonts/$DIST -maxdepth 1 -type f )`
	printURL $PUBLOCAL $PUBDOWNLOAD1 $LOCALFILES >>$FILETO || fatal "Error with mirror 1 ($PUBLOCAL with '$LOCALFILES' in '$DIST' dir) (possible files are missed!)"
	echo
	if [ -n "$PUBDOWNLOAD2" ] ; then
		echo >>$FILETO
		echo "Украина:" >>$FILETO
		printURL $PUBLOCAL $PUBDOWNLOAD2 $LOCALFILES >>$FILETO || fatal "Error with mirror 2 "
		#echo "Полный список файлов доступен
	fi
	cat >>$FILETO <<EOF

При необходимости эти же файлы могут быть получены через http: замените ftp:// на http:// в пути.
Также Вы можете напрямую зайти в каталог, чтобы загрузить файлы открытой и закрытой части:
	$PUBDOWNLOAD1HTTP
	$DOWNLOADDIR/$TYPE-$WINENUMVERSION/$DIST

Обязательно ознакомьтесь с известными проблемами в текущей сборке:
http://wiki.etersoft.ru/WINE/knownbugs

Ответы на основные вопросы смотрите на http://etersoft.ru/wine/faq

При возникновении затруднений со скачиванием файлов просим привести
описание проблемы в ответе на данное письмо.

Благодарим Вас за покупку!
-- 
Команда разработчиков
Etersoft, 2008
EOF
}

build_wine()
{
	VERNAME=$PRODUCTNAME/$WINENUMVERSION

	TARGETDIR=/var/ftp/pub/download/WINE@Etersoft/$TARGETDIRNAME
	DOWNLOADDIR="ftp://updates.etersoft.ru/pub/download/WINE@Etersoft/$TARGETDIRNAME"
	
	# FIXME: use $WINEPUB_PATH-$WINENUMVERSION here
	PUBLOCAL="/var/ftp/pub/Etersoft/$VERNAME"

	# Use real path if possible
	if [ -L "$PUBLOCAL" ] ; then
		PUBLOCAL=`readlink -f "$PUBLOCAL"`
		VERNAME=$PRODUCTNAME/`basename $PUBLOCAL`
	fi

	if [ ! -d "$PUBLOCAL/WINE/$DIST" ] ; then
		warning "System $DIST not supported for build ($PUBLOCAL/WINE/$DIST does not exist)"
		do_broken
	fi
	
	TEXTDIST=$DIST
	# Check for linked system (собираем для основной системы)
	if [ -L "$PUBLOCAL/WINE/$DIST" ] ; then
		DIST=`readlink $PUBLOCAL/WINE/$DIST | sed -e "s|\.\./||g"`
		TEXTDIST="$TEXTDIST (фактически сборка выполнена для $DIST)"
	fi
	
	
	# TODO: Пока отдаём только со своего ftp
	#if [ "$RELEASECANDIDAT" = "1" ] ; then
	if false ; then
		PUBDOWNLOAD1="ftp://updates.etersoft.ru/pub/Etersoft/$VERNAME"
		PUBDOWNLOAD1HTTP=
	else
		#PUBDOWNLOAD1="http://ftp.freesource.info/etersoft/$PRNAME"
		#PUBDOWNLOAD1="http://etersoft.ru/download/$PRNAME"
		PUBDOWNLOAD1="ftp://updates.etersoft.ru/pub/Etersoft/$VERNAME"
		PUBDOWNLOAD1HTTP="http://updates.etersoft.ru/pub/Etersoft/$VERNAME"
		PUBDOWNLOAD1FONTS="http://updates.etersoft.ru/pub/Etersoft/$VERNAME/fonts/$DIST"
		# TODO: select 
		PUBDOWNLOAD1CIFS="http://updates.etersoft.ru/pub/Etersoft/$VERNAME/CIFS/$DIST"
		#PUBDOWNLOAD1CIFS="http://updates.etersoft.ru/pub/Etersoft/CIFS@Etersoft/3.3-linux-cifs/$DIST"
		#PUBDOWNLOAD2="ftp://ftp.linux.kiev.ua/pub/mirrors/ftp.etersoft.ru/$PRNAME"
	fi
 
	#PUBDOWNLOAD1="ftp://updates.etersoft.ru/pub/Etersoft/$PRNAME/WINE/$DIST"
	
	# grep line for DIST
	export REBUILDLIST=`grep -v "^#" lists/rebuild.list.all | grep "^$DIST" | head -n1`
	
	if [ -z "$REBUILDLIST" ] ; then
		warning "Destination $DIST is not supported for build (missed in $REBUILDLIST)"
		do_broken
	fi
	
	echo "Work with $TASK for $REBUILDLIST"

	case $PRODUCTVAR in
		*Lite*)
			build_networklite
			;;
		*Network*)
			build_network
			;;
		*Local*)
			build_local
			;;
		*SQL*)
			build_sql
			;;
		*)
			fatal "Unknown product $PRODUCTVAR"
			;;
	esac

	# Проверяем, действительно ли создался целевой файл
	[ -r "$EFILE" ] || fatal "Can't find result file $EFILE"

	# Для отправки писем обязательно нужна локаль!
	export LANG=ru_RU.UTF-8
	TMPMAIL=`mktemp`
	prepareMail $TMPMAIL || fatal "Can't prepare letter"
	cat $TMPMAIL | mutt "${FULLMAILTO}" -b "wine@etersoft.ru" -s "Сборка $PRODUCTVAR" || fatal "Can't send"
	rm -f $TMPMAIL
}


# Ошибка: не ловятся ошибки отсюда
prepareSeltaMail()
{
	local FILETO BETA
	FILETO=$1
	>$FILETO
	NAME=`get_name "$FULLNAME"`
	BETA=""
	cat >>$FILETO <<EOF
${DEAR} ${NAME}!

Ваш заказ Продукта ${PRODUCTVAR} (релиз $WINENUMVERSION) выполнен.
${BETA}
Регистрационный номер Продукта: ${ETERREGNUM}.

Для получения Продукта необходимо скачать файлы по приведённым ссылкам:

Установочный пакет SELTA@Etersoft (файл selta.msi) и файл лицензии (selta.lic):
EOF
	LOCALFILES=selta.msi
	printURL $PUBLOCAL $PUBDOWNLOAD1 $LOCALFILES >>$FILETO || fatal "Error with mirror 1 ($PUBLOCAL with '$LOCALFILES') (possible files are missed!)"
	printURL $FTPDIR $DOWNLOADDIR/$WINENUMVERSION `( cd $FTPDIR && find -L ./ -maxdepth 1 -type f | sed -e "s|\./||g" )` >>$FILETO || fatal "Error with private part (files are missed) "

	cat >>$FILETO <<EOF

Пакеты PostgreSQL для системы ${TEXTDIST} (файлы postgresql*):
EOF

	LOCALFILES=`( cd $PGLOCAL ; find -L $DIST -maxdepth 1 -type f)`
	printURL $PGLOCAL $PGDOWNLOAD1 $LOCALFILES >>$FILETO || fatal "Error with mirror 1 ($PGLOCAL with '$LOCALFILES') (possible files are missed!)"


	cat >>$FILETO <<EOF

Документация и краткая инструкция по установке доступна по адресу
http://wiki.etersoft.ru/SELTA

При необходимости эти же файлы могут быть получены через http: замените ftp:// на http:// в пути.

Скачать сборки PostgreSQL под другие системы можно здесь:
	$PGDOWNLOAD1

При возникновении затруднений со скачиванием файлов просим привести
описание проблемы в ответе на данное письмо.

Благодарим Вас за покупку!
-- 
Команда разработчиков
Etersoft, 2008
EOF
}

build_selta()
{
	PRODUCTNAME="SELTA@Etersoft"
	VERNAME=$PRODUCTNAME/$WINENUMVERSION
	
	PUBLOCAL="/var/ftp/pub/Etersoft/$VERNAME/Windows"
	PUBDOWNLOAD1="ftp://updates.etersoft.ru/pub/Etersoft/$VERNAME/Windows"

	PGLOCAL="/var/ftp/pub/Etersoft/PostgreSQL/8.2"
	PGDOWNLOAD1="ftp://updates.etersoft.ru/pub/Etersoft/PostgreSQL/8.2"
	
	TARGETDIR=/var/ftp/pub/download/SELTA@Etersoft/$TARGETDIRNAME
	DOWNLOADDIR="http://updates.etersoft.ru/pub/download/SELTA@Etersoft/$TARGETDIRNAME"

	
	if [ ! -d "$PGLOCAL/$DIST" ] ; then
		warning "System $DIST not supported for build ($PGLOCAL/$DIST does not exist)"
		do_broken
	fi
	
	TEXTDIST=$DIST
	# Check for linked system (собираем для основной системы)
	if [ -L "$PGLOCAL/$DIST" ] ; then
		DIST=`readlink $PGLOCAL/$DIST | sed -e "s|\.\./||g"`
		TEXTDIST="$TEXTDIST (фактически сборка выполнена для $DIST)"
	fi
	
	# grep line for DIST
	export REBUILDLIST=`grep -v "^#" lists/rebuild.list.all | grep $DIST`
	
	if [ -z "$REBUILDLIST" ] ; then
		warning "Destination $DIST is not supported for build (missed in $REBUILDLIST)"
		do_broken
	fi

	echo "Work with $TASK for $REBUILDLIST"

	export FTPDIR=$TARGETDIR/$WINENUMVERSION
	# Можем стирать только каталог дистрибутива, а не весь
	test -d $FTPDIR && rm -rf $FTPDIR
	mkdir -p $FTPDIR || fatal "error with $FTPDIR creating"

	export ETERREGNUM
	echo >> $ALOGDIR/autobuild.report.log
	echo "Build $TYPE for $ETERREGNUM in $FTPDIR" >> $ALOGDIR/autobuild.report.log

	# Вывод скрипта не записывается в лог
	export BUILDSTRAP=
	#

# Подпись
	unset DISPLAY
	# Ключ в private_key.dsa
	cd sig
	#LICENSE_FILE=$TARGETDIRNAME.lic
	LICENSE_FILE=selta.lic
	test -r $LICENSE_FILE && fatal "Some license file already exists"
#TYPE_LICENSE=Corporate
cat <<EOF >$LICENSE_FILE
VERSION=$WINENUMVERSION
LICENSE_NUMBER=$ETERREGNUM
OWNER=$OWNER
RESPONSIBLE=$FULLNAME
TYPE_LICENSE=$TYPE_LICENSE
DATE_START=$DATE_START
DATE_END=$DATE_END
EOF
	rm -f $LICENSE_FILE.sig
	wine generate_sig.exe $LICENSE_FILE
	rm -f $LICENSE_FILE
	test -r $LICENSE_FILE.sig || fatal "Can't sign license file"
	mv -f $LICENSE_FILE.sig $FTPDIR/$LICENSE_FILE || fatal "Can't move license file to $FTPDIR"
	cd -
	#export BUILDNAME=wine-etersoft-$type
	#build_rpm $BUILDNAME || fatal "Build failed"

	# Каталог уже создаётся сборкой пакета
	#cd $FTPDIR && { md5sum *.* >MD5SUM ; cd - ; }
	# вставить номер в readme и в каталог
# поменять
	#sed -e "s/XXXX-XXXX/$ETERREGNUM/g" <$WINEETER_PATH-$WINENUMVERSION/docs/README_$TYPE.html >$FTPDIR/README.html || fatal "readme copying"
	#sed -e "s/XXXX-XXXX/$ETERREGNUM/g" <$WINEETER_PATH-$WINENUMVERSION/docs/license_$type.html >$FTPDIR/license.html || fatal "license copying"
	#cp -f $WINEETER_PATH-$WINENUMVERSION/docs/${type}_manual.html $FTPDIR/manual.html || fatal "manual copying"

	# Проверяем, действительно ли создался целевой файл
	#[ -r "$EFILE" ] || fatal "Can't find result file $EFILE"

	# Для отправки писем обязательно нужна локаль!
	export LANG=ru_RU.UTF-8
	TMPMAIL=`mktemp`
	prepareSeltaMail $TMPMAIL || fatal "Can't prepare letter"
	cat $TMPMAIL | mutt "${FULLMAILTO}" -b "wine@etersoft.ru" -s "Сборка $PRODUCTVAR" || fatal "Can't send"
	rm -f $TMPMAIL
}

# Выходить при любой неприятности
# TODO:
#CAREBUILD=1
# TODO: изменить название. очищать каталог hasher
export NIGHTBUILD=1

#fatal "По техническим причинам отгрузка приостановлена."

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
