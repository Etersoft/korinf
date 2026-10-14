#!/bin/bash

# Using:
#  script [--nostop] [--force|--init|--check] System/Version [target version]
# --force -- force rebuild from any state
# --check -- print check list
# --init  -- install build requires before build
# --noinst  -- don't install after build
# --nostop  -- don't stop on errors

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

DIRNAME="$(dirname $0)"
cd $DIRNAME

. ./functions

set_ver "$@"

DISTR="$1"

wine32_disabled()
{
    local system="${DISTR#x86_64/}"
    system="${system#i586/}"
    local list=../etc/wine-disabled-32
    [ -r "$list" ] || return 1
    grep -Fqx "$system" "$list" || grep -Fqx "${system%%/*}" "$list"
}

# TODO
#if [ -n "$INIT" ] ; then
#    ../bin/korinf $DISTR --remove
#fi

dosh()
{
    local cmd="$1"
    shift
    local i j rc
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

case "$ver" in
    7.13)
        if echo "$DISTR" | grep -q "x86_64/" ; then
            # x86_64
            do_bootstrap wine-gecko wine-mono winetricks wine-etersoft
            do_build wine-etersoft-local wine-etersoft-network wine-grdwine
        fi

        # x86
        if wine32_disabled ; then
            echo "Skip disabled 32-bit WINE components for $DISTR"
        else
            DISTR="$(echo "$DISTR" | sed -e "s|x86_64/|i586/|")"
            do_bootstrap wine-gecko wine-mono winetricks wine32-etersoft
            do_build wine32-grdwine
        fi
        ;;
    9*wow64*)
        if echo "$DISTR" | grep -q "x86_64/" ; then
            # x86_64
            do_bootstrap eepm wine-etersoft-gecko wine-etersoft-mono wine-etersoft-winetricks wine-etersoft
            do_build wine-etersoft-local wine-etersoft-network wine-etersoft-grdwine
        fi
        ;;
    7*|8*|9*|10*)
        if echo "$DISTR" | grep -q "x86_64/" ; then
            # x86_64
            do_bootstrap eepm wine-etersoft-gecko wine-etersoft-mono wine-etersoft-winetricks wine-etersoft
            do_build wine-etersoft-local wine-etersoft-network wine-etersoft-grdwine
        fi

        # x86
        if wine32_disabled ; then
            echo "Skip disabled 32-bit WINE components for $DISTR"
        else
            DISTR="$(echo "$DISTR" | sed -e "s|x86_64/|i586/|")"
            do_bootstrap eepm wine-etersoft-gecko wine-etersoft-mono wine-etersoft-winetricks wine32-etersoft
            do_build wine32-etersoft-grdwine
        fi
        ;;
    11*)
        if echo "$DISTR" | grep -q "x86_64/" ; then
            # x86_64
            do_bootstrap eepm wine-etersoft-gecko wine-etersoft-mono wine-etersoft-winetricks wine-etersoft
            do_build wine-etersoft-local wine-etersoft-network wine-etersoft-grdwine
        fi

        # x86
        if wine32_disabled ; then
            echo "Skip disabled 32-bit WINE components for $DISTR"
        else
            DISTR="$(echo "$DISTR" | sed -e "s|x86_64/|i586/|")"
            do_bootstrap eepm wine-etersoft-gecko wine-etersoft-mono wine-etersoft-winetricks wine32-etersoft
            do_build wine32-etersoft-grdwine
        fi
        ;;
    1*|2*)
        # x86_64
        do_bootstrap wine-etersoft
        do_build wine-etersoft-local wine-etersoft-network wine-etersoft-sql
        #wine-grdwine
        ;;
    *)
        fatal "Unknown version $ver"
esac

if [ "$STATE" = "--check" ] ; then
    echo "Legend: MIS - missed, OBS - obsoleted build, ABF - autobuild failed, FIL - manual build failed"
fi
