#!/bin/sh

. /usr/share/eterbuild/eterbuild

fatal()
{
	echo "Error $@"
	exit 1
}


jump_to_repo()
{
	cd $TEMPREPODIR/ || fatal
	
	if ! test -d $WORKBRANCH ; then
		git clone $REPO $WORKBRANCH || fatal "can't clone $REPO"
		cd $WORKBRANCH
		git checkout -b $WORKBRANCH $REPOALIAS/$WORKBRANCH || fatal "can't checkout"
		exit
	fi
	cd $WORKBRANCH
}


update_version()
{
	local SPECNAME=etersoft/wine-etersoft.spec
	test -f VERSION && test -f $SPECNAME || fatal "incorrect current dir $(pwd) or repo"

	git reset --soft HEAD^

	echo "WINE@Etersoft version $(get_version $SPECNAME)-eter$(get_numrelease $SPECNAME)" >VERSION
	# rebuild needed files
	autoreconf -f || fatal "autoreconf failed"

	#git commit --amend VERSION configure include/config.h.in
	git commit -C ORIG_HEAD
}

pull_and_log()
{
	# check repo
	git rev-parse HEAD >/dev/null || fatal "check repo failed"

	# save TAG for last commit
	TAG=$(git rev-parse HEAD)

	# try pull and exit if all up-to-date
	gpull -c $REPOALIAS $WORKBRANCH && { tty -s && echo "No work" ; exit ; }

	NEWTAG=$(git rev-parse HEAD)

	[ "$TAG" = "$NEWTAG" ] && fatal "last commit is not changed after update"

	# сформировать лог, обновить spec с пред. момента до обновления
	rpmlog -s -l $TAG

	# обновляем VERSION и объединяем с предыдущим коммитом
	update_version
}

pub_and_push()
{
	# публикуем на сборку
	rpmpub -r $WORKTARGET

	# will works only if REPOALIAS is origin :)
	gpush $REPOALIAS $WORKBRANCH || fatal
}

ETERBUILDDIR=/srv/$USER/Projects/git/etersoft-build-utils/bin
[ -d "$ETERBUILDDIR" ] || ETERBUILDDIR=$HOME/Projects/etersoft-build-utils/bin
[ -d "$ETERBUILDDIR" ] || fatal "can't find eterbuild dir"
export PATH=$ETERBUILDDIR:$PATH
