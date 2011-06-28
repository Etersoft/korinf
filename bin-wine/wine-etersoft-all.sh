#!/bin/sh

DIR=$(dirname $0)

export ALLOWPUBLICDEBUG=0

for i in sql network local ; do
	$DIR/wine-etersoft-$i.sh $@
done
