#!/bin/sh -x

cp -f test.task.orig test.task
TASKDIR=$(pwd)
touch $TASKDIR/SALESDIR
$(pwd)/hands/worker.sh $TASKDIR
rm -f $TASKDIR/SALESDIR
