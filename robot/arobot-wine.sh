#!/bin/sh -x
##
#  Korinf project
#
#  Publish WINE@Etersoft product for client by task file
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
	build_package $BUILDNAME || fatal "Build failed"

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
	PROJECTNAME="WINE@Etersoft"
	VERNAME=$PROJECTNAME/$WINENUMVERSION

	TARGETDIR=/var/ftp/pub/download/WINE@Etersoft/$TARGETDIRNAME
	DOWNLOADDIR="ftp://updates.etersoft.ru/pub/download/WINE@Etersoft/$TARGETDIRNAME"
	
	# FIXME: use $WINEPUB_PATH-$WINENUMVERSION here
	PUBLOCAL="/var/ftp/pub/Etersoft/$VERNAME"

	# Use real path if possible
	if [ -L "$PUBLOCAL" ] ; then
		PUBLOCAL=`readlink -f "$PUBLOCAL"`
		VERNAME=$PROJECTNAME/`basename $PUBLOCAL`
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

