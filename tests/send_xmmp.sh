#/!bin/sh
##
#  Korinf project
#
#  Copyright (c) Etersoft <http://etersoft.ru> 2010
#  Copyright (c) Vitaly Lipatov <lav@etersoft.ru> 2010
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

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod messages/jabber

shift
SUBJECT="$1"
shift
send_by_jabber -s "$SUBJECT" $@
