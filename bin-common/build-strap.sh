#!/bin/sh
# 2005, 2006, 2007, 2008, 2009 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

# install packages after build
export BOOTSTRAP=1

TARGET="$1"
shift
arg="$1"
#shift

build_eepm()
{
    ./eepm.sh $TARGET $1
}

build_rpm_build()
{
    ./rpm-build-altlinux-compat.sh $TARGET $1
}


if [ -z "$arg" ] ; then
    shift
    build_rpm_build -i
    build_rpm_build -b

    build_eepm -i
    build_eepm -b
    exit
fi

build_rpm_build "$@" || exit
build_eepm "$@" || exit
