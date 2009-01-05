#!/bin/sh
# 2005-2006 (c) Etersoft www.etersoft.ru
# Public domain

. /etc/rpm/etersoft-build-functions

export WORKDIR=../functions
test -f $WORKDIR/config.in && . $WORKDIR/config.in || fatal "Can't locate config.in"

#ALPHA=-$WINENUMVERSION
ALPHA=-1.0

false && for PATHTO in $WINEPUB_PATH$ALPHA $WINEETER_PATH$ALPHA; do
#for PATHTO in $WINEETER_PATH$ALPHA; do
	echo "Test rpms in $PATHTO"
	find -L $PATHTO -name "*.rpm" -print0 | xargs -0 rpm --checksig || fatal "broken rpm"
	echo "Test gzips in $PATHTO"
	find -L $PATHTO -name "*.tgz" -print0 | xargs -0 gzip -t || fatal "broken tgz"
	echo "Test bzips in $PATHTO"
	find -L $PATHTO -name "*.tbz" -print0 | xargs -0 bzip -t || fatal "broken tbz"
	echo "Test bzip2s in $PATHTO"
	find -L $PATHTO -name "*.tbz2" -print0 | xargs -0 bzip -t || fatal "broken tbz2"
	echo "Test makeself archives in $PATHTO"
	find -L $PATHTO -name "*.run" -print0 | xargs -0 -IQQQ sh QQQ --check || fatal "broken run"
done

PATHTO=$WINEPUB_PATH$ALPHA

#exit 1
# Note: we exclude tarballs
# TODO: --links не работает?
#EXCLUDE='--exclude "*Special*"'
EXCLUDE="--links --copy-unsafe-links"
echo "--------- Sync: etersoft"
false && rsync -va --partial --progress --stats --delete \
	--exclude "*update-from*" $EXCLUDE \
 	-e ssh $PATHTO/ etersoft:download/WINE@Etersoft$ALPHA/

echo "--------- Sync: freesource"
rsync -va --partial --progress --stats --delete \
	$EXCLUDE \
 	-e ssh $PATHTO/ ftp.freesource:/var/ftp/etersoft/WINE@Etersoft$ALPHA/
#ssh ftp.freesource.info "ln -s WINE@Etersoft$ALPHA /var/ftp/etersoft/WINE@Etersoft"

#rsync -va --partial --progress --stats --delete-after \
# 	-e ssh etersoft:download/WINE@Etersoft$ALPHA/WINE/ $PATHTO/WINE/
