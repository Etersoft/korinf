#!/bin/sh

priv_update_changelog()
{
for sp in $SUBSPEC ; do
	SPECNAME=wine-etersoft-$sp.spec
	test -f VERSION && test -f $SPECNAME || fatal "incorrect current dir $(pwd) or repo"
	# CURTAG and NEWTAG defined in pull_changes
	rpmlog -r -l $SPECNAME $CURTAG $NEWTAG || fatal "can't rpmlog"
	# uncommit
	git reset --soft HEAD^
	# обновляем VERSION и объединяем с предыдущим коммитом
done

# we will get spec version from sql spec
SPECNAME=wine-etersoft-sql.spec

ETERVERSION="$(get_version $SPECNAME)-eter$(get_numrelease $SPECNAME)"
echo "WINE@Etersoft version $ETERVERSION" >VERSION
# rebuild needed files
autoreconf -f || fatal "autoreconf failed"

git commit -a -m "auto build $ETERVERSION with $(basename $0) script"
}


priv_pub_and_push()
{
for sp in $SUBSPEC ; do
	SPECNAME=wine-etersoft-$sp.spec
	# публикуем на сборку
	# Hack for cad
	#if [ $sp = "cad" ] ; then
	#	rpmpub -r cad $SPECNAME
	#else
	rpmpub -r $WORKTARGET $SPECNAME
	#fi
done

# will works only if REPOALIAS is origin :)
gpush $REPOALIAS $WORKBRANCH

save_good_state

# FIXME: some detect korinf placing
cd /srv/$USER/Projects/git/korinf/bin-wine 2>/dev/null || cd $HOME/Projects/korinf/bin-wine || fatal "can't CD"
./wine-etersoft-all.sh -f test $WORKTARGET
cd -
}
