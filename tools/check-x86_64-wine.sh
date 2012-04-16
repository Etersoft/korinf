#!/bin/bash

HASHER=$TMPDIR/hasher
APT_CONFIG=$HOME/etc/apt.conf.x86_64.M51
WINE_PUB_DIR=/var/ftp/pub/Etersoft/WINE@Etersoft/1.0.12/WINE/ALTLinux/5.1
WINE_PVT_DIR=/var/ftp/pvt/Etersoft/WINE@Etersoft/1.0.12/WINE-SQL/ALTLinux/5.1
LICENSE_PVT_DIR=/var/ftp/pvt/Etersoft/WINE@Etersoft/license


# Prepare hasher
mkdir -p $HASHER
hsh-rmchroot $HASHER
rm -rf $HASHER/aptbox
mkaptbox --apt-config=$APT_CONFIG $HASHER
hsh-mkchroot $HASHER
hsh-initroot $HASHER

I586_PACKAGES="i586-libcups i586-libalsa i586-libX11 i586-libXext i586-libXpm i586-libfreetype \
    i586-libusb i586-libssl7 i586-libSM i586-libnatspec i586-glibc-locales\
    i586-libSM i586-libnatspec i586-libXt i586-libXaw i586-libXrender\
    i586-libxml2 i586-libldap2.4 i586-fontconfig i586-libgcc4.4\
    i586-libieee1284 i586-liblcms webclient \
    su fonts-ttf-liberation"

hsh-install $HASHER $I586_PACKAGES

cp $WINE_PUB_DIR/wine-etersoft-*.rpm $HASHER/chroot/.in/
cp $WINE_PVT_DIR/wine-etersoft-sql-*.rpm $HASHER/chroot/.in/
cp $LICENSE_PVT_DIR/wine-etersoft.lic $HASHER/chroot/.in/


# Install WINE@Etersoft
cat <<"EOF" >$HASHER/chroot/.host/install-wine.sh
#!/bin/sh
rpm -Uhv /.in/*.rpm
cp /.in/*.lic /etc/wine
EOF

chmod a+x $HASHER/chroot/.host/install-wine.sh
hsh-run --rooter $HASHER -- /.host/install-wine.sh


# Check WINE@Etersoft
hsh-install $HASHER xauth

cat <<"EOF" >$HASHER/chroot/.host/check-wine.sh
#!/bin/sh
export LANG=ru_RU.UTF-8
#export WINEPREFIX=/usr/src/.wine
#wine-glibc notepad
wine notepad
winediag
EOF

chmod a+x $HASHER/chroot/.host/check-wine.sh
hsh-run -Y $HASHER -- /.host/check-wine.sh
