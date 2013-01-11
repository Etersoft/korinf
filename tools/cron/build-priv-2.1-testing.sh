#!/bin/sh

# disable autorun from cron
#[ -z "$1" ] && exit

# Обновляет репозиторий и выкладывает новую сборку в случае необходимости

. $(dirname $0)/build-funcs.sh
. $(dirname $0)/build-funcs-priv.sh

TEMPREPODIR=/srv/$USER/Projects/autobuild/wine-priv
REPO=git.office:/projects/wine/wine-etersoft.git
REPOALIAS=origin
WORKBRANCH=master
WORKTARGET=2.1-testing
SUBSPEC="local sql network"

jump_to_repo

pull_changes || exit

priv_update_changelog

priv_pub_and_push
