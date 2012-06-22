#!/bin/sh

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod build/rpm
kormod check_reqs install mount korinf

#load_mod rpm

#testfile=$(echo /var/ftp/pub/Etersoft/RX@Etersoft/testing/CentOS/6/nxclient-*.i586.rpm)
#testfile=$(echo /var/ftp/pub/Etersoft/WINE@Etersoft/2.0-testing/Debian/6/fonts-ttf-liberation*)

#echo
#TARGETPATH=/var/ftp/pub/Etersoft/RX@Etersoft/testing
# alt
#VENDOR=$($DISTRVENDOR -s)
#PKGVENDOR=centos

#PKGFORMAT=rpm
# 
#DISTRVERSION=6

#BUILDARCH=i586

BUILDNAME=wine-etersoft

dist=Debian/6.0
parse_dist_name $dist
set_target_var

trap exit_handler EXIT HUP INT QUIT PIPE TERM

SOURCEPATH=/var/ftp/pub/Etersoft/WINE@Etersoft/2.0-testing/sources
BUILDSRPM=$(get_src_package "$SOURCEPATH" $BUILDNAME || fatal "Can't find package for $BUILDNAME")

mount_linux $dist || exit

install_req $dist

end_umount
