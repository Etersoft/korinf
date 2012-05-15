#!/bin/sh

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod build/rpm
load_mod rpm

testfile=$(echo /var/ftp/pub/Etersoft/RX@Etersoft/testing/CentOS/6/nxclient-*.i586.rpm)
#echo $testfile
#rpm --requires -p $testfile
echo
TARGETPATH=/var/ftp/pub/Etersoft/RX@Etersoft/testing
# alt
#VENDOR=$($DISTRVENDOR -s)
VENDOR=centos
# rpm
#TARGET=$($DISTRVENDOR -p)
TARGET=rpm
# 
#DISTRVERSION=12.04
dist_ver=6

BUILDARCH=i586

convert_deplist $testfile | tee test.file
diff -u /var/ftp/pub/Etersoft/RX@Etersoft/testing/ALTLinux/Sisyphus/log/nxclient*depends test.file
#rm -f test.file

