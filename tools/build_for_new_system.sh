#!/bin/sh

# Args:
# group (wine-group dir)
# package (package name)
# options (optionally)
build()
{
    local GROUP=$1
    local PACKAGE=$2
    local TARGET=$3
    local ARG=$4
    shift 4

    [ -n "$ARG" ] || ARG=-f

    echo
    # install needed packages
    ../bin-$GROUP/$PACKAGE.sh -i $SYSTEM $TARGET || exit
    # run build
    ../bin-$GROUP/$PACKAGE.sh $ARG $SYSTEM $TARGET $@ || exit
}


# Args:
# package (package name)
# options (optionally)
build_wc()
{
    local GROUP=wine
    local PACKAGE=$1
    local ARG=$2
    shift 2

    [ -n "$ARG" ] || ARG=-f

    echo
    # install needed packages
    ../bin-$GROUP/$PACKAGE.sh -i $SYSTEM $TARGET || exit
    # run build
    ../bin-$GROUP/$PACKAGE.sh $ARG $SYSTEM $TARGET $@ || exit
}

SYSTEM=$1
TARGET=$2
# Stop when error
export NIGHTBUILD=1

../bin-common/rpm-build-altlinux-compat.sh $SYSTEM -b || exit


######## WINE@Etersoft ############

#for BRANCH in 1.0.12 testing school school-testing unstable
build wine fonts-ttf-liberation stable
build wine fonts-ttf-ms stable

# build and install wine
build wine wine-etersoft stable -b
build wine wine-etersoft-all stable

#build wine wine-etersoft-cad

# build hasp without target
build hasp haspd stable
# TODO: only for dkms target
# build hasp dkms-aksparlnx

# build cifs without target
build cifs etercifs stable
# TODO: only for dkms target
#build cifs dkms-etercifs stable


######## RX@Etersoft ###########

build nx stable -b
build nx rx-etersoft stable
build nx nxclient stable
build nx nxsadmin stable
build nx opennx stable

########## Postgre@Etersoft ############

build postgres icu38 stable -b
build postgres postgre-etersoft9.0 stable
