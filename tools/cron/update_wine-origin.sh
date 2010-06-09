#!/bin/sh
mkdir -p /srv/wine/Projects/wine-origin

cd /srv/wine/Projects/wine-origin || exit 1

#git clone http://git.etersoft.ru/projects/eterwine.git
#git pull origin pure
# fetch due tags
#git fetch winehq

#git pull winehq master
# try pull and exit if all up-to-date
gpull -c winehq master && { echo "No work now" ; exit 0; }

#autoconf -f
# rm -f libs/wine/version.c
./configure --prefix=/usr || exit 1
make depend || exit 1
jmake || exit 1
./wine --version || exit 1
