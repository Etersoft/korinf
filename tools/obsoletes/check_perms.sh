#!/bin/sh

. /etc/rpm/etersoft-build-functions

WORKDIR=/var/ftp/pvt/Etersoft
. $WORKDIR/config.in

ALPHA=-$WINENUMVERSION

for i in $WINEPUB_PATH$ALPHA/ $WINEETER_PATH$ALPHA/ $WINEETER_PATH$ALPHA-Local/ $WINEETER_PATH$ALPHA-Network/ ; do
	echo "Check in $i ..."
	find $i -maxdepth 5  \( ! -perm /o+r \) -type f
	# | xargs chmod o+r
	find $i -maxdepth 5  \( ! -perm /o+rx \) -type d
done