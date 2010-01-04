#!/bin/sh
# 2010 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod messages/jabber

send_by_jabber -s "Hello" $USER@im.etersoft.ru <<EOF
Hello, test!
EOF
