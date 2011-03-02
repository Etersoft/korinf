#!/bin/sh

# For initial create repo
# git clone http://source.winehq.org/git/wine.git wine-origin
# git remote add winehq http://source.winehq.org/git/wine.git

MAILTO=wine-devel@lists.etersoft.ru
#MAILTO=lav@etersoft.ru

ORIGINBRANCH=origin

. /usr/share/eterbuild/eterbuild

cd /srv/wine/Projects/eterwine || exit 1

# check repo
git rev-parse HEAD >/dev/null || fatal "check repo failed"

# save TAG for last commit
OLDTAG=$(git rev-parse HEAD)

# Cleanup before update
git checkout -f

# try pull and exit if all up-to-date
gpull -c $ORIGINBRANCH master && { echocon "No work now" ; exit 0; }
# FIXME: как я понимаю, не присылаются теги
gpull $ORIGINBRANCH master || { echocon "Some update error" ; exit 0; }

NEWTAG=$(git rev-parse HEAD)

[ "$OLDTAG" = "$NEWTAG" ] && return

#exit

autoconf -f
./configure --prefix=/usr || exit 1
#make depend || exit 1
jmake || exit 1
./wine --version || exit 1
