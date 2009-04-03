#!/bin/bash

. ./config.in

#WINE_PATH=/var/ftp/pub/Etersoft/WINE@Etersoft/WINE
#DIST_PATH=/var/www/sites/etersoft/updates/Wine@Etersoft/Local/supn1437GETinternal
DIST_PATH=/var/ftp/pub/Etersoft/rest/Local/supn1437GETinternal
WINEVERSION="1.0 Local"
#WINEETER_PATH=/var/ftp/pvt/Etersoft/WINE@Etersoft/WINE
# see config.in
#VERSION=0.9-local

exit_handler()
{
    local rc=$?
    trap - EXIT
    rm -r  "$TMPDIR_WINE"
    exit $rc
}

trap exit_handler EXIT HUP INT QUIT PIPE TERM

# see config.in for DISTR_LIST

#DISTR_LIST=`find   -L  -maxdepth 2 -mindepth 2 -type d`

for DIST in $DISTR_LIST ; do
    DIST=`echo $DIST | sed -e "s|^./||"`
    echo "Создаем для $DIST"
    mkdir -p $DIST_PATH/$DIST/
    
    NAME_DISTR=`echo ${DIST/\//-} | tr [A-Z] [a-z]`

    TMPDIR_WINE=`mktemp -t -d make_wine.XXXXXX` || exit 1
    
    FULL_ARCH=wine-full-$VERSION-$NAME_DISTR
    ETER_ARCH=wine-eter-$VERSION-$NAME_DISTR
    mkdir -p $TMPDIR_WINE/{$FULL_ARCH,$ETER_ARCH}
    
    # Copying all files from dirs (only files with .)
    cp $WINEPUB_PATH/WINE/$DIST/*.* $TMPDIR_WINE/$FULL_ARCH
    cp $WINEETER_PATH/WINE/$DIST/*.* $TMPDIR_WINE/$FULL_ARCH
    
    cp $WINEETER_PATH/WINE/$DIST/*.* $TMPDIR_WINE/$ETER_ARCH
    
    makeself.sh --notemp $TMPDIR_WINE/$FULL_ARCH $DIST_PATH/$DIST/$FULL_ARCH.run \
    	"Uncompressing WINE@Etersoft $WINEVERSION"   || exit 1

    makeself.sh --notemp $TMPDIR_WINE/$ETER_ARCH $DIST_PATH/$DIST/$ETER_ARCH.run \
    	"Uncompressing WINE@Etersoft $WINEVERSION"   || exit 1
    
    rm -r  $TMPDIR_WINE
done
