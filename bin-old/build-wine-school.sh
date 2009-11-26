#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License
#
. functions/helpers.sh

# default target
#export REBUILDLIST=lists/rebuild.list.all
# custom target
#export REBUILDLIST="FreeBSD/6.2 FreeBSD/6.3 FreeBSD/7.0"
#export REBUILDLIST="Special/3.0"
#export REBUILDLIST="Debian/3.1"
#export REBUILDLIST="Ubuntu/8.04"
#export REBUILDLIST="LinuxXP/2006"
#export REBUILDLIST="CentOS/5 ALTLinux/4.0 ALTLinux/Sisyphus Scientific/4.1 Ubuntu/8.04"
export REBUILDLIST="CentOS/5"
#export REBUILDLIST="ALTLinux/4.0"
#export REBUILDLIST="SUSE/10.3 SUSE/10.1 SUSE/10"
#export REBUILDLIST="Fedora/9"

#export WINENUMVERSION=current
#export WINENUMVERSION=1.0.9

export BASEPATH=/var/ftp/pvt/Etersoft/School
export FTPDIR=$BASEPATH/WINE/

export MAINFILES="wine-school[-_][0-9] libwine-school[-_][0-9] libwine-school-gl[-_][0-9]"
export EXTRAFILES="libwine-school-devel[-_][0-9] libwine-school-twain[-_][0-9]"
# libwine-school-doc[-_][0-9]"

# install packages after build
#export BOOTSTRAP=1
build_rpm wine-school

unset MAINFILES EXTRAFILES
build_rpm wine-school-components
