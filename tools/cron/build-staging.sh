#!/bin/sh

# Обновляет репозиторий и выкладывает новую сборку в случае необходимости

#. $(dirname $0)/build-funcs.sh

TEMPREPODIR=/srv/$USER/Projects/autobuild

WORKTARGET=last

# FIXME: some detect korinf placing
cd /srv/$USER/Projects/git/korinf/bin-wine 2>/dev/null || cd $HOME/Projects/korinf/bin-wine || fatal "can't CD"
./wine-staging.sh -f test $WORKTARGET
cd -
