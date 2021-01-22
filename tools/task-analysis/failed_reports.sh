#!/usr/bin/env bash


SALESDIR="/srv/builder/sales"

for i in $(ls $SALESDIR/*.failed)
do
    DIST=$(grep DIST "$i")
    DOWNLOADDIR=$(grep DOWNLOADDIR "$i")
    LASTCAUSE=$(tail -n 1 "$i")
    echo -e "\n==>" $i "<=="
    echo -e $DIST | sed 's/=/:\t\t/'
    echo -e $DOWNLOADDIR | sed 's/=/:\t/'
    echo -e "CAUSE:\t\t"$LASTCAUSE
done
