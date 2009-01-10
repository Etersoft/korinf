#!/bin/sh -x
##
#  Korinf project
#
#  Publish SELTA@Etersoft product for client by task file
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
	PROJECTNAME="SELTA@Etersoft"
	VERNAME=$PROJECTNAME/$WINENUMVERSION
	
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

