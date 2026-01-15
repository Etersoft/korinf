#!/bin/sh

PACKAGELIST="nx-libs nxagent nxproxy nxssh prunner rx-etersoft rxclient rx-etersoft-pcsc rx-etersoft-pcsc-driver rxclient-pcsc rx-etersoft-kdrive rxkdriveclient" #rx-etersoft-usbip"

LOCALDIR="/var/ftp/pvt/Etersoft/RX@Etersoft/1.8/x86_64/"
DIST="ALTLinux/p11"
for i in $PACKAGELIST ; do
	n="$(echo $LOCALDIR/$DIST/$i[-_][0-9]*)"
	[ -r "$n" ] && echo "$i found" || echo "Missed $i package in $LOCALDIR/$DIST"
done
