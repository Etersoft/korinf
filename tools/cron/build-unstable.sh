#!/bin/sh

fatal()
{
	echo "Error $@"
	exit 1
}

TEMPREPODIR=/srv/$USER/Projects

export LC_ALL=C

cd $TEMPREPODIR/ || fatal

REPO=git.office:/projects/eterhack.git
if ! test -d eterhack ; then
	git clone $REPO || fatal "can't clone $REPO"
	git checkout -b eterhack origin/eterhack || fatal "can't checkout eterhack"
	cd eterhack
else
	cd eterhack
	git pull origin eterhack || fatal "can't pull"
fi

cd etersoft || fatal "can't cd"

rpmpub -r unstable wine-etersoft.spec

cd /srv/$USER/Projects/git/korinf/bin-wine || cd $HOME/Projects/korinf/bin-wine || fatal "can't CD"

./wine-etersoft.sh test unstable
