#!/bin/sh

for i in $(echo ~/sales/*) ; do
	test -f $i || continue
	test "$(cat $i | wc -l)" -lt 5 || continue
	#echo $i
	ORFILE=$(basename $i .broken)
	ORFILE=$(basename $ORFILE .failed)
	#echo $ORFILE
	test ~/sales/copytsks/$ORFILE.tsk || echo "Missed copy for $ORFILE"
	rm -v $i
	cp -v ~/sales/copytsks/$ORFILE.tsk ~/sales/$ORFILE
done
