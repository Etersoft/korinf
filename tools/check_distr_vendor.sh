#!/bin/sh
# Check detection code in OS root tree
OS=/net/os/stable
cd $OS
export DISTR_LIST=`find -L -maxdepth 2 -mindepth 2 -type d | sed -e "s|^./||" | sort | grep -v Windows`
cd -

DISTRVENDOR=distr_info

#echo $DISTR_LIST

for i in $DISTR_LIST ; do
	test -d $OS/$i/etc || continue
	export ROOTDIR=$OS/$i
	DISTR=$($DISTRVENDOR -e)
	#echo -n "$i detected as $DISTR  "
	#[ "$i" = "$DISTR" ] && echo "$i detected as $DISTR"
	[ "$i" = "$DISTR" ] || echo "$i NOT detected, get $DISTR"
	#../bin/distr_vendor -p
done
