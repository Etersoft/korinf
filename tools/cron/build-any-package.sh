#!/bin/sh

# Обновляет репозиторий и выкладывает новую сборку в случае необходимости

. $(dirname $0)/build-funcs.sh

# git.office:/projects/wine/wine-etersoft.git
REPO=$1
# /var/ftp/pub/Etersoft/RX@Etersoft/$USER/sources
TARGETDIR=$2

test -n "$*" || fatal

REPONAME=$(basename $REPO .git)
TEMPREPODIR=/srv/$USER/Projects/autobuild-any

#### jump_to_repo
mkdir -p $TEMPREPODIR/ && cd $TEMPREPODIR/ || fatal

if test -d $REPONAME ; then
        cd $REPONAME
else
	docmd git clone $REPO $REPONAME || fatal "can't clone $REPO"
	echo "Return to prev step for force gpull -c"
	cd $REPONAME
	docmd git reset --hard HEAD^
fi

reset_to_good_state

##### pull_changes

# try pull with fast-forward and exit if all up-to-date
if docmd gpull -c ; then
    echocon "No work"
    save_good_state
    exit
fi

# Если тэг не на последнем коммите, обновляем changelog
if ! is_last_commit_tag ; then
    docmd rpmlog -r -l || docmd rpmlog -r -l $PREVCOMMIT || fatal "can't rpmlog"
    #git commit -a -m "auto build with $(basename $0) script"
fi

###### publish
mkdir -p $TARGETDIR
docmd rpmpub $TARGETDIR || exit


#docmd korinf $REPONAME $TARGETDIR || exit
docmd /home/lav/Projects/git/korinf/bin/korinf $REPONAME $TARGETDIR || exit

docmd gpush || exit

save_good_state
