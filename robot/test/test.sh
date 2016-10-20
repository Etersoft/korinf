#!/bin/sh

AROBOTDIR=$(pwd)/..

#cp tasks/test-postgres.task ./try.task
#cp tasks/test-rx.task ./try.task
#cp tasks/test-wine-etersoft.task ./try.task
#cp tasks/test-rx.task ./try.task
#cp tasks/test-selta-license-only.task ./try.task
#cp tasks/test-rx-license-only.task ./try.task
#cp tasks/test-wine-etersoft-cad.task ./try.task
#cp tasks/test-wine-etersoft-enterprise.task ./try.task
cp tasks/test-wine-etersoft-enterprise-license-only.task ./try.task
#cp tasks/test-wine.task ./try.task
#cp tasks/test-selta.task ./try.task
$AROBOTDIR/hands/buildtask.sh --debug try.task
