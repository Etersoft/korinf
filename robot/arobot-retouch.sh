#!/bin/sh
##
#  Korinf project
#
#  Ставит провалившиеся задания опять на сборку
#
#  Copyright (c) Etersoft <http://etersoft.ru> 2005, 2006, 2007, 2009
#  Copyright (c) Vitaly Lipatov <lav@etersoft.ru> 2009
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.

#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
##


DIRNAME=`dirname $0`
[ "$DIRNAME" = "." ] && DIRNAME=`pwd`
cd $DIRNAME/..

. functions/helpers.sh
ALOGDIR=$ALOGDIR-arobot

switch_to_builder $DIRNAME/`basename $0`

#pwd
cd ~/sales
#ls -l
#exit 1

if [ -z "$1" ] ; then
	for i in *.failed ; do
		test -f $i || continue
		mv -v $i `basename $i .failed` || exit 1
	done
else
	for i in *.broken ; do
		test -f $i || continue
		mv -v $i `basename $i .broken` || exit 1
	done
fi
cd -

