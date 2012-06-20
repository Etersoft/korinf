#!/bin/sh

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod check_built
#load_mod rpm

# use external $BUILDSRPM $DESTDIR $MAINFILESLIST

DESTDIR=/var/ftp/pvt/Etersoft/WINE@Etersoft/2.0-testing/WINE-SQL/ALTLinux/Sisyphus
SOURCEPATH=/var/ftp/pvt/Etersoft/WINE@Etersoft/2.0-testing/sources

BUILDNAME=wine-etersoft-sql
BUILDSRPM=$(get_src_package "$SOURCEPATH" $BUILDNAME || fatal "Can't find package for $BUILDNAME")

MAINFILESLIST=$BUILDNAME
do_need_build_package $BUILDNAME && echo NEED
