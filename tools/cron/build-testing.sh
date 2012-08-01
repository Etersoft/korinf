#!/bin/sh

# Обновляет репозиторий и выкладывает новую сборку в случае необходимости

. $(dirname $0)/build-funcs.sh

TEMPREPODIR=/srv/$USER/Projects/autobuild
REPO=git.office:/projects/wine/eterhack.git
REPOALIAS=origin
WORKBRANCH=eter-1.0.12
WORKTARGET=testing

jump_to_repo
pull_and_log -s
pub_and_push

korinf_wine -f test $WORKTARGET

