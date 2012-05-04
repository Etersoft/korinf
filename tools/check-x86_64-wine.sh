#!/bin/bash

# Script for testing wine install
# http://bugs.etersoft.ru/show_bug.cgi?id=4550

WINEVER=2.0
ALTVER=p6
PRIVPART=SQL

WINE_PUB_DIR=/var/ftp/pub/Etersoft/WINE@Etersoft/$WINEVER/WINE/ALTLinux/$ALTVER
WINE_PVT_DIR=/var/ftp/pvt/Etersoft/WINE@Etersoft/$WINEVER/WINE-$PRIVPART/ALTLinux/$ALTVER
LICENSE_FILE=/var/ftp/pvt/Etersoft/WINE@Etersoft/license/wine-etersoft-2.0.lic

# Здесь нужна проверка архитектуры
# Надо уметь проверять 32 и 64 бита


I586_PACKAGES="i586-libcups i586-libalsa i586-libX11 i586-libXext i586-libXpm i586-libfreetype \
    i586-libusb i586-libssl7 i586-libSM i586-libnatspec i586-glibc-locales\
    i586-libSM i586-libnatspec i586-libXt i586-libXaw i586-libXrender\
    i586-libxml2 i586-libldap2.4 i586-fontconfig i586-libgcc4.4\
    i586-libieee1284 i586-liblcms webclient \
    su fonts-ttf-liberation"

#hsh-install $HASHER $I586_PACKAGES
# Install needed packages
loginhsh -b $ALTVER -i -t -q $WINE_PUB_DIR/wine-etersoft-*.rpm $WINE_PVT_DIR/wine-etersoft-sql-*.rpm

HASHERDIR=$(loginhsh -d -b $ALTVER -t)
cp $LICENSE_FILE $HASHERDIR/chroot/.in/

cat <<"EOF" >$HASHERDIR/chroot/.host/check-wine.sh
#!/bin/sh
export LANG=ru_RU.UTF-8
export WINEPREFIX=/usr/src/.wine
mkdir -p $WINEPREFIX
cp /.in/wine-etersoft.lic $WINEPREFIX/
wine cmd /V
winediag
EOF

chmod a+x $HASHERDIR/chroot/.host/check-wine.sh
loginhsh -x -b $ALTVER -t -r /.host/check-wine.sh
