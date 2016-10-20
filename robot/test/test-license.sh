#!/bin/sh -x

AROBOTDIR=$(pwd)/..

. $AROBOTDIR/funcs/common
. $AROBOTDIR/funcs/task
. $AROBOTDIR/funcs/license

#cp tasks/test-wine.task ./try.task
cp tasks/test-wine-etersoft-enterprise.task ./try.task

load_task ./try.task
create_license test.lic $AROBOTDIR/dsa/wine-etersoft.dsa
