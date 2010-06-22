#!/bin/sh

. /usr/share/eterbuild/eterbuild

cd /srv/wine/Projects/wine-origin || exit 1

#git clone http://git.etersoft.ru/projects/eterwine.git

# try pull and exit if all up-to-date
gpull -c winehq master && { echocon "No work now" ; exit 0; }

autoreconf -f
./configure --prefix=/usr || exit 1
#make depend || exit 1
jmake || exit 1
./wine --version || exit 1
