#!/bin/sh

AROBOTDIR=$(pwd)/..

cp tasks/test-wine-etersoft.task ./try.task
#cp tasks/test-wine.task ./try.task
#cp tasks/test-selta.task ./try.task
$AROBOTDIR/arobot.sh try.task
