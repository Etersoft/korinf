#!/bin/sh

# Build CRYPTO@Etersoft for a system (the robot's system build task runs it,
# like bin-rx/build-rx-bootstrap-new.sh for RX@Etersoft):
#  script [--nostop] [--force|--init|--check] System/Version [target version]
# --force -- force rebuild from any state
# --check -- print check list
# --init  -- install build requires before build
# --nostop  -- don't stop on errors
#
# Components: ecryptomgr and wine-etersoft-cpcsp_proxy for the system, and
# wine32-etersoft-cpcsp_proxy for the i586 companion of an x86_64 system
# (as robot/products/crypto delivers them).

NOSTOP=''

STATE=''
while [ -n "$1" ] ; do
    case "$1" in
        --nostop)
            NOSTOP=1
            shift
            ;;
        --force|--init|--check|--noinst)
            STATE="$1"
            shift
            ;;
        -*)
            echo "Error: unknown arg $1. Run with System/Version as arg"
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

. ./functions

set_ver "$@"

DISTR="$1"

dosh()
{
    local cmd="$1"
    shift
    local i j rc=0
    for i in "$@" ; do
        for j in $cmd ; do
            echo
            echo
            echo "> ./$i.sh $DISTR $ver $j"
            ./$i.sh $DISTR $ver $j || { rc=$?; [ -n "$NOSTOP" ] || exit $rc ; }
        done
    done
    return 0
}

do_check()
{
    local i
    for i in "$@" ; do
        echo
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
        *)
            dosh "-b" "$@"
            ;;
    esac
}

do_bootstrap ecryptomgr wine-etersoft-cpcsp_proxy

if echo "$DISTR" | grep -q "^x86_64/" ; then
    # the i586 companion
    DISTR="$(echo "$DISTR" | sed -e "s|^x86_64/||")"
    do_bootstrap wine32-etersoft-cpcsp_proxy
fi

[ "$STATE" = "--check" ] && echo "Legend: MIS - missed, OBS - obsoleted build, ABF - autobuild failed, FIL - manual build failed"
exit 0
