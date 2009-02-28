#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script

DELUSER=$1

if [ -z $2] ; then
	DELGROUP=$1
else
	DELGROUP=$2
fi

userdel $DELUSER 
groupdel $DELGROUP 2> /dev/null"
