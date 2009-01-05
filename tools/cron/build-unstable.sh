#!/bin/sh

fatal()
{
	echo "Error $@"
	exit 1
}
TEMPREPODIR=/home/lav/Projects/WINE/

cd $TEMPREPODIR/ || fatal

