#!/bin/sh
# Выводит сообщения о ненайденных вайновским configure библиотеках
#

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

[ -n "$1" ] && VERSION=$1 || VERSION=1.0.9-eter38
NAME=$WINEPUB_PATH/$VERSION

for n in $(get_distro_list $NAME) ; do
	echo
	FILE=$NAME/WINE/$n/log/wine.log.bz2
	echo "$n: (`stat -c "%y" $FILE`)"
	bzcat $FILE | grep "configure:" | grep development | grep found | sed -e "s|^configure:|          |g"
done
