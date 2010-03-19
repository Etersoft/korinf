#!/bin/sh

for i in sql network local ; do
	./wine-etersoft-$i.sh $@
done
