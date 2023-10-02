#!/bin/sh

# Using:
#  script [--force|--init|--check] System/Version [target version]
# --force -- force rebuild from any state
# --check -- print check list
# --init  -- install build requires before build
# --noinst  -- don't install after build

STATE=''
case "$1" in
    --force|--init|--check|--noinst)
        STATE="$1"
        shift
        ;;
    -*)
        echo "Error: unknown arg $1. Run with System/Version as arg"
        exit 1
esac

. ./functions

set_ver "$@"

DISTR="$1"

# TODO
#if [ -n "$INIT" ] ; then
#    ../bin/korinf $DISTR --remove
#fi

dosh()
{
    local cmd="$1"
    shift
    local i j
    for i in "$@" ; do
        for j in $cmd ; do
            ./$i.sh $DISTR $ver $j || exit
        done
    done
    return 0
}

do_check()
{
    local i
    for i in "$@" ; do
        ./$i.sh $DISTR $ver -q -c
    done
    return 0
}

do_bootstrap()
{
    case "$STATE" in
        --check)
            do_check "$@"
            ;;
        --force)
            dosh "-I -B" "$@"
            ;;
        --init)
            dosh "-i -b" "$@"
            ;;
        --noinst)
            do_build "$@"
            ;;
        *)
            dosh "-b" "$@"
            ;;
    esac
}

do_build()
{
    case "$STATE" in
        --check)
            do_check "$@"
            ;;
        --force)
            dosh "-I -F" "$@"
            ;;
        --init)
            dosh "-i -f" "$@"
            ;;
        *)
            dosh "-f" "$@"
            ;;
    esac
}

do_bootstrap nx nxssh rx-etersoft
do_build rx-etersoft-pcsc rx-etersoft-smartcard rxclient

[ "$STATE" = "--check" ] && echo "Legend: MIS - missed, OBS - obsoleted build, ABF - autobuild failed, FIL - manual build failed"
