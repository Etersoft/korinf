#!/bin/sh

fatal()
{
	echo "Error $@"
	exit 1
}

TEMPREPODIR=/srv/$USER/Projects
WORKBRANCH=eter-1.0.12
WORKTARGET=testing

cd $TEMPREPODIR/ || fatal

REPO=git.office:/projects/eterhack.git
if ! test -d $WORKBRANCH ; then
	git clone $REPO $WORKBRANCH || fatal "can't clone $REPO"
	git checkout -b $WORKBRANCH origin/$WORKBRANCH || fatal "can't checkout eterhack"
	cd $WORKBRANCH
else
	cd $WORKBRANCH
	git pull origin $WORKBRANCH || fatal "can't pull"
fi

cd etersoft || fatal "can't cd"

rpmpub wine-etersoft.spec

cd /srv/$USER/Projects/git/korinf/bin-wine || cd $HOME/Projects/korinf/bin-wine || fatal "can't CD"

./wine-etersoft.sh test $WORKTARGET
