#!/bin/sh

AROBOTDIR=$(pwd)/..

cp tasks/test-wine-etersoft.task ./try.task
$AROBOTDIR/arobot.sh try.task
