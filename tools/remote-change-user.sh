#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script

NEWUSER=$1
NEWGROUP=$2
OLDUSER=$3
OLDGROUP=$4
ATIME=`date +%T`

mkdir -p /home/$NEWUSER
#user:
cp /etc/passwd /etc/passwd.old.$ATIME
sed "s|$OLDUSER|$NEWUSER|g" /etc/passwd > /etc/passwd.tmp
mv -f /etc/passwd.tmp /etc/passwd
rm -f /etc/passwd.tmp

cp /etc/shadow /etc/shadow.old.$ATIME
sed "s|$OLDUSER|$NEWUSER|g" /etc/shadow > /etc/shadow.tmp
mv -f /etc/shadow.tmp /etc/shadow
rm -f /etc/shadow.tmp
#group:
cp /etc/group /etc/group.old.$ATIME
sed "s|$OLDGROUP|$NEWGROUP|g" /etc/group > /etc/group.tmp
mv -f /etc/group.tmp /etc/group
rm -f /etc/group.tmp

cp /etc/gshadow /etc/gshadow.old.$ATIME
sed "s|$OLDGROUP|$NEWGROUP|g" /etc/gshadow > /etc/gshadow.tmp
mv -f /etc/gshadow.tmp /etc/gshadow
rm -f /etc/gshadow.tmp