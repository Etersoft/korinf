#!/bin/sh
#find /var/ftp/pub/Etersoft/CIFS@Etersoft.cc -mindepth 1 -maxdepth 1 -type d | xargs -n1 ./remove_obsoleted_srpms.sh linux-cifs
#find /var/ftp/pub/Etersoft/Postgre@Etersoft -mindepth 1 -maxdepth 1 -type d | xargs -n1 ./remove_obsoleted_srpms.sh postgre-etersoft
for i in local network sql cad ; do
	find /var/ftp/pvt/Etersoft/WINE@Etersoft -mindepth 1 -maxdepth 1 -type d | xargs -n1 ./remove_obsoleted_srpms.sh wine-etersoft-$i
done

