#!/bin/sh

export ALLOWPUBLICDEBUG=0

for i in sql network local ; do
	./wine-etersoft-$i.sh $@
done
