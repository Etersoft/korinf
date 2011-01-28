#!/bin/sh

# For initial create repo
# git clone http://source.winehq.org/git/wine.git wine-origin
# git remote add winehq http://source.winehq.org/git/wine.git

MAILTO=wine-devel@lists.etersoft.ru
#MAILTO=lav@etersoft.ru

. /usr/share/eterbuild/eterbuild

cd /srv/wine/Projects/wine-origin || exit 1

# check repo
git rev-parse HEAD >/dev/null || fatal "check repo failed"

# save TAG for last commit
OLDTAG=$(git rev-parse HEAD)

# Cleanup before update
git checkout -f

# try pull and exit if all up-to-date
gpull -c winehq master && { echocon "No work now" ; exit 0; }
gpull winehq master || { echocon "Some update error" ; exit 0; }

NEWTAG=$(git rev-parse HEAD)

[ "$OLDTAG" = "$NEWTAG" ] && return

LINES=$(git log $OLDTAG..$NEWTAG --author=".*@etersoft.ru" --pretty=short)

# FIXME: нужно исправить кодировку присылаемых писем
if [ -n "$LINES" ] ; then
	(	echo "New Etersoft's patches since last build time:"
		git log $OLDTAG..$NEWTAG --author=".*@etersoft.ru" --pretty=short ; 
		echo; echo "---" ; echo
		git log $OLDTAG..$NEWTAG -U --author=".*@etersoft.ru" ) | \
		LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8 mutt -s "Eter's patch is applied to winehq repo $(date "+%x")" $MAILTO
fi

#exit

autoconf -f
./configure --prefix=/usr || exit 1
#make depend || exit 1
jmake || exit 1
./wine --version || exit 1
gpush pure master || exit 1
