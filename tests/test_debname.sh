#!/bin/sh

# 2012 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod convert

check()
{
	[ "$2" != "$3" ] && echo "FATAL with '$1': result '$2' do not match with '$3'" || echo "OK for '$1' with '$2'"
}

checkname()
{
	check "$1" `internal_get_deb_pkgname_from_rpm "$1"` "$2"
}

PKGVENDOR=ubuntu
checkname libpq5.2-9.0eter-9.0.4-alt14.i586.rpm libpq5.2-9.0eter_9.0.4-eter14ubuntu_i386.deb
checkname postgre-etersoft9.0-9.0.4-alt14.i586.rpm postgre-etersoft9.0_9.0.4-eter14ubuntu_i386.deb
checkname postgre-etersoft9.0-contrib-9.0.4-alt14.i586.rpm postgre-etersoft9.0-contrib_9.0.4-eter14ubuntu_i386.deb
checkname postgre-etersoft9.0-seltaaddon-9.0.4-alt14.i586.rpm postgre-etersoft9.0-seltaaddon_9.0.4-eter14ubuntu_i386.deb
checkname postgre-etersoft9.0-server-9.0.4-alt14.i586.rpm postgre-etersoft9.0-server_9.0.4-eter14ubuntu_i386.deb
checkname postgre-etersoft9.0-9.0.4-alt14.x86_64.rpm postgre-etersoft9.0_9.0.4-eter14ubuntu_amd64.deb
