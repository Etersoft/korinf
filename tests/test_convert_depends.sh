#!/bin/sh

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod build/rpm convert
load_mod rpm

testfile=$(echo /var/ftp/pub/Etersoft/RX@Etersoft/testing/CentOS/6/nxclient-*.i586.rpm)
#testfile=$(echo /var/ftp/pub/Etersoft/WINE@Etersoft/2.0-testing/Debian/6/fonts-ttf-liberation*)

echo
TARGETPATH=/var/ftp/pub/Etersoft/RX@Etersoft/testing
# alt
#VENDOR=$($DISTRVENDOR -s)
PKGVENDOR=centos

PKGFORMAT=rpm
# 
DISTRVERSION=6

BUILDARCH=i586
echo "==="
get_target_deplist $(get_pkgname_from_filename $testfile) | tee test.file
echo "==="
diff -u /var/ftp/pub/Etersoft/RX@Etersoft/testing/ALTLinux/Sisyphus/log/nxclient*depends test.file
#rm -f test.file

