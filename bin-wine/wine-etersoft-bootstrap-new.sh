#!/bin/sh

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
            echo "> ./$i.sh $DISTR $ver $j"
            ./$i.sh $DISTR $ver $j || { [ -z "$NOSTOP" ] && exit ; }
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

case "$ver" in
    1*|2*)
        # x86_64
        do_bootstrap wine-etersoft
        do_build wine-etersoft-local wine-etersoft-network wine-etersoft-sql
        #wine-grdwine
        ;;
    7.13)
        if echo "$DISTR" | grep -q "x86_64/" ; then
            # x86_64
            do_bootstrap wine-gecko wine-mono winetricks wine-etersoft
            do_build wine-etersoft-local wine-etersoft-network wine-grdwine
        fi

        # x86
        DISTR="$(echo "$DISTR" | sed -e "s|x86_64/||")"
        do_bootstrap wine-gecko wine-mono winetricks wine32-etersoft
        do_build wine32-grdwine
        ;;
    7*|8*)
        if echo "$DISTR" | grep -q "x86_64/" ; then
            # x86_64
            do_bootstrap wine-etersoft-gecko wine-etersoft-mono wine-etersoft-winetricks wine-etersoft
            do_build wine-etersoft-local wine-etersoft-network wine-etersoft-grdwine
        fi

        # x86
        DISTR="$(echo "$DISTR" | sed -e "s|x86_64/||")"
        do_bootstrap wine-etersoft-gecko wine-etersoft-mono wine-etersoft-winetricks wine32-etersoft
        do_build wine32-etersoft-grdwine
        ;;
    *)
        fatal "Unknown version $ver"
esac

[ "$STATE" = "--check" ] && echo "Legend: MIS - missed, OBS - obsoleted build, ABF - autobuild failed, FIL - manual build failed"
