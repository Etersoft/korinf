#!/bin/sh
#find /var/ftp/pub/Etersoft/WINE@Etersoft -mindepth 1 -maxdepth 1 -type d | xargs -n1 ./remove_not_in_distro.sh WINE
#find /var/ftp/pub/Etersoft/WINE@Etersoft -mindepth 1 -maxdepth 1 -type d | xargs -n1 ./remove_not_in_distro.sh fonts
#find /var/ftp/pub/Etersoft/CIFS@Etersoft -mindepth 1 -maxdepth 1 -type d | xargs -n1 ./remove_not_in_distro.sh
find /var/ftp/pub/Etersoft/RX@Etersoft -mindepth 1 -maxdepth 1 -type d | xargs -n1 ./remove_not_in_distro.sh

#for i in Local Network SQL CAD School ; do
#	find /var/ftp/pvt/Etersoft/WINE@Etersoft -mindepth 1 -maxdepth 1 -type d | xargs -n1 ./remove_not_in_distro.sh WINE-$i
#done
