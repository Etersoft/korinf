#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script

NEWUSER=$1
if [ -z $2] ; then
	NEWGROUP=$1
else
	NEWGROUP=$2
fi

groupadd $NEWGROUP 2> /dev/null 
useradd -g $NEWGROUP -d /home/$NEWUSER -s /bin/bash $NEWUSER
#test
#	$SUDO chroot $TESTDIR su - -c "mkdir -p /tmp/add-user"