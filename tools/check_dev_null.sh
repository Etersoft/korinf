#!/bin/sh

# Check for no char device /dev/null
export DISTR_LIST="/net/os/stable/i586/*/* /net/os/stable/x86_64/*/*"
echo $DISTR_LIST

for i in $DISTR_LIST ; do
	test -d $i/bin || continue
	test -c $i/dev/null && continue #echo "/dev/null is ok on $i" 
	ls -l $i/dev/null
done

