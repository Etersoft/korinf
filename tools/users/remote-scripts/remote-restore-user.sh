#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script



restore_users()
{
    pushd /etc
    #user:
    CHTIME=`ls -l | grep passwd.old | awk '{print($8)}' | tail -n 1`
    echo "$CHTIME for passwd"
    if [ -e /etc/passwd.old.$CHTIME* ] ; then
        echo "Deleting wrong /etc/passwd"
        rm -f /etc/passwd
        echo "Copying old /etc/passwd"
        cp /etc/passwd.old.$CHTIME* /etc/passwd
    else
        echo "Check for old /etc/passwd"
    fi

    CHTIME=`ls -l | grep shadow.old | awk '{print($8)}' | tail -n 1`
    echo "$CHTIME for shadow"
    if [ -e /etc/shadow.old.$CHTIME* ] ; then
        echo "Deleting wrong /etc/shadow"
        rm -f /etc/shadow
        echo "Copying old /etc/shadow"
        cp /etc/shadow.old.$CHTIME* /etc/shadow
    else
        echo "Check for old /etc/shadow"
    fi

    #group:
    CHTIME=`ls -l | grep group.old | awk '{print($8)}' | tail -n 1`
    echo "$CHTIME for group"
    if [ -e /etc/group.old.$CHTIME* ] ; then
        echo "Deleting wrong /etc/group"
        rm -f /etc/group
        echo "Copying old /etc/passwd"
        cp /etc/group.old.$CHTIME* /etc/group
    else
        echo "Check for old /etc/group"
    fi

    CHTIME=`ls -l | grep gshadow.old | awk '{print($8)}' | tail -n 1`
    echo "$CHTIME for gshadow"
    if [ -e /etc/gshadow.old.$CHTIME* ] ; then
        echo "Deleting wrong /etc/gshadow"
        rm -f /etc/gshadow
        echo "Copying old /etc/passwd"
        cp /etc/gshadow.old.$CHTIME* /etc/gshadow
    else
        echo "Check for old /etc/group"
    fi
    popd
}

test_fun()
{
	mkdir -p testdir_fun_$CHTIME
}

restore_users
#test_fun