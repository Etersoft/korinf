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


update_wine_version()
{
	local SPECNAME=etersoft/wine-etersoft.spec
	test -f VERSION && test -f $SPECNAME || fatal "incorrect current dir $(pwd) or repo"

	git reset --soft HEAD^

	echo "WINE@Etersoft version $(get_version $SPECNAME)-eter$(get_numrelease $SPECNAME)" >VERSION
	# rebuild needed files
	autoreconf -f || fatal "autoreconf failed"

	#git commit --amend VERSION configure include/config.h.in
	git commit -a -C ORIG_HEAD
}

pull_changes()
{
	# check repo
	git rev-parse HEAD >/dev/null || fatal "check repo failed"

	# save TAG for last commit
	CURTAG=$(git rev-parse HEAD)

	# try pull (with rebase) and exit if all up-to-date
	gpull -c $REPOALIAS $WORKBRANCH && { echocon "No work" ; exit ; }

	NEWTAG=$(git rev-parse HEAD)

	NEWVEREL="$(get_version $SPECNAME)-alt$(get_numrelease $SPECNAME)"
	NEWRELTAG=$(git rev-parse "$NEWVEREL")

	[ "$CURTAG" = "$NEWTAG" ] && fatal "last commit is not changed after update"

	# Если тег стоит на последнем коммите, не трогаем changelog (т.е. кто-то вручную сборку сделал)
	[ "$NEWTAG" = "$NEWRELTAG" ] && return 1
	return 0
}

step_version()
	local CURTAG=$1
	# сформировать лог, обновить spec с пред. момента до обновления
	rpmlog -s -l $CURTAG

	# обновляем VERSION и объединяем с предыдущим коммитом
	update_wine_version
}

pull_and_log()
{
	pull_changes || return
	# CURTAG defined in pull_changes
	step_version $CURTAG
}

pub_and_push()
{
	# публикуем на сборку
	rpmpub -r $WORKTARGET

	# will works only if REPOALIAS is origin :)
	gpush -t $REPOALIAS $WORKBRANCH && return

	# if push is failed
	git reset --hard $CURTAG
}

korinf_wine()
{
	# FIXME: some detect korinf placing
	cd /srv/$USER/Projects/git/korinf/bin-wine 2>/dev/null || cd $HOME/Projects/korinf/bin-wine || fatal "can't CD"
	./wine-etersoft.sh $1 $2
	cd -
}


ETERBUILDDIR=/srv/$USER/Projects/git/etersoft-build-utils/bin
[ -d "$ETERBUILDDIR" ] || ETERBUILDDIR=$HOME/Projects/etersoft-build-utils/bin
[ -d "$ETERBUILDDIR" ] || fatal "can't find eterbuild dir"
export PATH=$ETERBUILDDIR:$PATH

export LC_ALL=C
