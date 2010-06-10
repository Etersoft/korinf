#!/bin/sh

# Обновляет репозиторий и выкладывает новую сборку в случае необходимости

. $(dirname $0)/build-funcs.sh

export LC_ALL=C

TEMPREPODIR=/srv/$USER/Projects
REPO=git.office:/projects/eterhack.git
REPOALIAS=origin
WORKBRANCH=eterhack
WORKTARGET=unstable

jump_to_repo
pull_and_log
pub_and_push

cd /srv/$USER/Projects/git/korinf/bin-wine || cd $HOME/Projects/korinf/bin-wine || fatal "can't CD"

./wine-etersoft.sh test $WORKTARGET

