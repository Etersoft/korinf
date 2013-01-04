#!/bin/sh

. /usr/share/eterbuild/eterbuild
load_mod git

SPECNAME=etersoft/wine-etersoft.spec

fatal()
{
	echo "Error $@"
	exit 1
}


jump_to_repo()
{
	mkdir -p $TEMPREPODIR/ || fatal
	cd $TEMPREPODIR/ || fatal
	
	if ! test -d $WORKBRANCH ; then
		git clone $REPO $WORKBRANCH || fatal "can't clone $REPO"
		cd $WORKBRANCH
		git checkout -b $WORKBRANCH $REPOALIAS/$WORKBRANCH || fatal "can't checkout"
		exit
	fi
	cd $WORKBRANCH
	reset_to_good_state
}


update_wine_version()
{
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
	if gpull -c $REPOALIAS $WORKBRANCH ; then
		echocon "No work"
		save_good_state
		exit
	fi

	NEWTAG=$(git rev-parse HEAD)

	# получаем по спеку предполагаемое название тэга
	# FIXME: проверять просто на тэг
	NEWVEREL="$(get_version $SPECNAME)-alt$(get_numrelease $SPECNAME)"
	NEWRELTAG=$(git rev-parse "$NEWVEREL^0")

	[ "$CURTAG" = "$NEWTAG" ] && fatal "last commit is not changed after update"

	# Если тег стоит на последнем коммите, не трогаем changelog (т.е. кто-то вручную сборку сделал)
	[ "$NEWTAG" = "$NEWRELTAG" ] && echo "Skip, last commit has appropriate tag" && return 1
	is_last_commit_tag && echo "Skip, last commit has last tag (checked with is_last_commit_tag)" && return 1
	return 0
}

step_version()
{
	# сформировать лог, обновить spec с пред. момента до обновления
	rpmlog $1 -l $CURTAG

	# обновляем VERSION и объединяем с предыдущим коммитом
	update_wine_version
}

pull_and_log()
{
	pull_changes || return
	# CURTAG defined in pull_changes
	step_version $@
}

pub_and_push()
{
	# публикуем на сборку
	rpmpub -r $WORKTARGET

	# will works only if REPOALIAS is origin :)
	gpush $REPOALIAS $WORKBRANCH

	save_good_state
}

korinf_wine()
{
	# FIXME: some detect korinf placing
	cd /srv/$USER/Projects/git/korinf/bin-wine 2>/dev/null || cd $HOME/Projects/korinf/bin-wine || fatal "can't CD"
	./wine-etersoft.sh "$@"
	cd -
}

# save PREVCOMMIT
reset_to_good_state()
{
	if [ -r prevcommit ] ; then
		PREVCOMMIT=$(cat prevcommit)
		docmd git reset --hard $PREVCOMMIT
	fi
	rm -rfv .git/rebase-apply
	rm -f prevcommit
	docmd git clean -d -f
	# recreate prevcommit after git clean
	PREVCOMMIT=$(git rev-parse HEAD)
	echo $PREVCOMMIT > prevcommit
}

save_good_state()
{
	rm -f prevcommit
}

ETERBUILDDIR=/srv/$USER/Projects/git/etersoft-build-utils/bin
[ -d "$ETERBUILDDIR" ] || ETERBUILDDIR=$HOME/Projects/etersoft-build-utils/bin
[ -d "$ETERBUILDDIR" ] || fatal "can't find eterbuild dir"
export PATH=$ETERBUILDDIR:$PATH

export LC_ALL=C
