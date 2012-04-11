#!/bin/sh

# Обновляет репозиторий и выкладывает новую сборку в случае необходимости

. $(dirname $0)/build-funcs.sh

TEMPREPODIR=/srv/$USER/Projects/wine-priv
REPO=git.office:/projects/wine/wine-etersoft.git
REPOALIAS=origin
WORKBRANCH=eter-2.0.0
WORKTARGET=2.0-testing

jump_to_repo

pull_changes || exit

for sp in local sql network ; do
	SPECNAME=wine-etersoft-$sp.spec
	test -f VERSION && test -f $SPECNAME || fatal "incorrect current dir $(pwd) or repo"
	# CURTAG and NEWTAG defined in pull_changes
	rpmlog -r -l $SPECNAME $CURTAG $NEWTAG
	# uncommit
	git reset --soft HEAD^
	# обновляем VERSION и объединяем с предыдущим коммитом
done

# we will get spec version from sql spec
SPECNAME=wine-etersoft-sql.spec

echo "WINE@Etersoft version $(get_version $SPECNAME)-eter$(get_numrelease $SPECNAME)" >VERSION
# rebuild needed files
autoreconf -f || fatal "autoreconf failed"

git commit -a --amend -m "auto build with $(basename $0) script"

pub_and_push

# FIXME: some detect korinf placing
cd /srv/$USER/Projects/git/korinf/bin-wine 2>/dev/null || cd $HOME/Projects/korinf/bin-wine || fatal "can't CD"
./wine-etersoft-all.sh test $WORKTARGET
cd -

