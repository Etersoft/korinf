#!/bin/sh

# Обновляет репозиторий и выкладывает новую сборку в случае необходимости

. $(dirname $0)/build-funcs.sh

TEMPREPODIR=/srv/$USER/Projects/autobuild
REPO=git.office:/projects/wine/eterhack.git
REPOALIAS=origin
WORKBRANCH=eterhack
WORKTARGET=unstable

jump_to_repo
pull_and_log -r
pub_and_push

korinf_wine -f test $WORKTARGET

