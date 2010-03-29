#!/bin/bash
# 2010 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod check_integrity

for EXT in deb rpm tgz tar.gz tar.bz2 tbz ; do
	for i in $(find $1 -type f -name "*.$EXT") ; do
		check_pkg_integrity $i && echo "Package $i is OK" || rm -vi $i
	done
done
