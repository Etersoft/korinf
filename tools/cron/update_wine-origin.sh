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

NEWTAG=$(git rev-parse HEAD)

[ "$OLDTAG" = "$NEWTAG" ] && exit 0

LINES=$(git log $OLDTAG..$NEWTAG --author=".*@etersoft.ru" --pretty=short)

# FIXME: нужно исправить кодировку присылаемых писем
if [ -n "$LINES" ] ; then
	(	echo "New Etersoft's patches since last build time:"
		git log $OLDTAG..$NEWTAG --author=".*@etersoft.ru" --pretty=short ; 
		echo; echo "---" ; echo
		git log $OLDTAG..$NEWTAG -U --author=".*@etersoft.ru" ) | \
		LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8 mutt -s "Eter's patch is applied to winehq repo $(date "+%x")" $MAILTO
fi

autoconf -f
if ./configure --prefix=/usr ; then
	#make depend || exit 1
	jmake
	./wine --version
fi
gpush pure master || exit 1
gpush -t pure master || exit 1

grep "not found" ./config.log
