#!/bin/sh

VERSION=1.0.9
RELEASE=39
#cd /var/ftp/pub/Etersoft/WINE@Etersoft/$VERSION/WINE/ALTLinux/4.1
cd /var/ftp/pub/Etersoft/WINE@Etersoft/$VERSION-eter$RELEASE/WINE/ALTLinux/Sisyphus
#cd /var/ftp/pub/Etersoft/WINE@Etersoft/current/WINE/ALTLinux/Sisyphus


LIST=
for i in wine libwine libwine-devel libwine-twain libwine-gl ; do
	rpm -q $i &>/dev/null && LIST="$LIST $i-$VERSION-*$RELEASE.*.rpm"
done

for i in libwine-devel libwine-twain libwine-gl ; do
	rpm -q $i &>/dev/null && LIST="$LIST extra/$i-$VERSION-*$RELEASE.*.rpm"
done

echo $LIST
rpmU $LIST $@ --force

