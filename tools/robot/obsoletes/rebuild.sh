#!/bin/sh
# Скрипт может быть запущен под любым пользователем, имеющем право на sudo под builder
# Скрипт осуществляет автоматическую пересборку пакета wine с отправкой результатов сборки по почте

# собираем каждый день из списка dayly (в current)
# раз в неделю собираем по списку weekly(в след. версию)

. /etc/rpm/etersoft-build-functions

cd `dirname $0`/..
export WORKDIR=`pwd`

. functions/helpers.sh

switch_to_builder $0 $@

# "", dayly, weekly
MODE=$1

# General
# Path to chroot dir (remote system mounted)
BUILD=/net/build

message()
{
	cat <<EOF
You can check build tree for ALT Linux Sisyphus on builder with
$ sudo su - builder
$ cd ~/RPM
or
$ cd /srv/builder/RPM
EOF
}

build()
{
	# remove old builds at midnight
	[ "$MODE" = "dayly" ] && rm -rf /srv/$USER/RPM/BUILD/*
	cd $HOME/Projects/wine-etersoft-public || fatal ""
	rm -f wine.spec freebsd/wine-etersoft-public/Makefile ebuild/wine-etersoft-public/wine-etersoft-public-1.0.ebuild
	cvs update || fatal "Can't cvs checkout"
	./wine-release.sh $VER
	rpmbb wine.spec --nodeps
	ERRSTATUS=$?
	message

	[ "$ERRSTATUS" = "0" ] || return
	[ -z "$MODE" ] && { echo "Done if it is day rebuild" ; return ; }
	# do only at night
	cd `dirname $0`/..
	# build other system
	# install after build
	export NIGHTBUILD=
	export WINENUMVERSION=current
	#[ $MODE = "weekly" ] && [ -d $WINEPUB_PATH/$WINENEXTVERSION ] && export WINENUMVERSION=$WINENEXTVERSION

	export REBUILDLIST=$WORKDIR/lists/rebuild.list.$MODE
	export BASEPATH=$WINEPUB_PATH/$WINENUMVERSION
	export MAINFILES="wine[-_][0-9] libwine[-_][0-9]"
	export EXTRAFILES="libwine-[!0-9]"
	build_rpm wine
	message
}

#VER=`date "+%Y%m%d"`
VER=`cat $WINEPUB_PATH/current/sources/tarball/wine-LAST`
export LANG=ru_RU.KOI8-R
if test -w /dev/stderr ; then
	build 2>&1 | tee /dev/stderr
else
	build 2>&1 
fi | mutt support@etersoft.ru -s "Autobuild WINE@Etersoft as $VER $MODE"
#build
date
