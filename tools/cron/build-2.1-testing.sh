#!/bin/sh

# Обновляет репозиторий и выкладывает новую сборку в случае необходимости

. $(dirname $0)/build-funcs.sh

TEMPREPODIR=/srv/$USER/Projects/autobuild
REPO=git.office:/projects/wine/eterhack.git
REPOALIAS=origin
WORKBRANCH=eter-2.1
WORKTARGET=2.1-testing

jump_to_repo
pull_and_log -r
pub_and_push

korinf_wine -f test $WORKTARGET

# run only on server
#cd $(dirname $0)/.. || exit
#./publish_wine_to_our_distro.sh 2.0
