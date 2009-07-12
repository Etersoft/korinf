#!/bin/sh
##
#  Korinf project
#
#  ������ ������������� ������� ����� �� ������.
#  ����� ������� �������� ������� ��� all ��� ���� �����
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


cd ~/sales || exit 1

DIST="$1"

if [ -z "$DIST" ] ; then
	echo "Run with target system name or 'all' for all tasks"
	exit 1
fi

if [ "$DIST" = "-c" ] ; then
	shift
	COMP="$1"
fi

if [ -n "$COMP" ] ; then
	echo "Reassign tasks for '$COMP' component"
	for i in *.failed ; do
		test -f $i || continue
		grep -q "COMPONENTNAME=\"$COMP\"" $i || continue
		mv -v $i `basename $i .failed` || exit 1
	done
	exit 0
fi

echo "Reassign tasks for '$DIST' distro"

if [ "$DIST" = "all" ] ; then
	DIST=""
fi

for i in *.failed ; do
	test -f $i || continue
	[ -z "$DIST" ] || grep -q "DIST=\"$DIST\"" $i || continue
	mv -v $i `basename $i .failed` || exit 1
done

for i in *.broken ; do
	test -f $i || continue
	[ -z "$DIST" ] || grep -q "DIST=\"$DIST\"" $i || continue
	mv -v $i `basename $i .broken` || exit 1
done

