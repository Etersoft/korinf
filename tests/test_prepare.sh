#!/bin/sh

# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod distro

ADEBUG=1

TARGET=rpm

MAINFILESLIST="m1 m2 m3"
EXTRAFILESLIST=
prepare_filelist

MAINFILESLIST=
EXTRAFILESLIST="e1 e2 e3"
prepare_filelist


MAINFILESLIST="m1 m2 m3"
EXTRAFILESLIST="e1 e2 e3"
prepare_filelist

MAINFILESLIST=
EXTRAFILESLIST="libicu38[-_][0-9] libicu38-devel[-_][0-9] icu38-samples[-_][0-9] icu38-utils[-_][0-9]"
prepare_filelist