#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script
. ../share/eterbuild/korinf/common
kormod mount

OLDUSER=$1
NEWUSER=$2
ATIME=`date +%X`

#user:
cp /etc/passwd /etc/passwd.old.$ATIME
sed 's|$OLDUSER|$NEWUSER|g' /etc/passwd > /etc/passwd.tmp
mv -f /etc/passwd.tmp /etc/passwd
rm -f /etc/passwd.tmp
#group:
cp /etc/group /etc/group.old.$ATIME
sed 's|$OLDUSER|$NEWUSER|g' /etc/group > /etc/group.tmp
mv -f /etc/group.tmp /etc/group
rm -f /etc/group.tmp
