#!/bin/sh

TARGET="$1"
[ -n "$TARGET" ] && shift || TARGET="all"
OPT="$1"

build_eepm()
{
    ./eepm.sh $TARGET $1 $OPT
}

build_rpm_build()
{
    ./rpm-build-altlinux-compat.sh $TARGET $1
}

for i in "" wine-2 wine-7 wine-7-unstable rx ; do
    KORINFMODULE="$i" build_eepm $1
    KORINFMODULE="$i" build_rpm_build $1
done
