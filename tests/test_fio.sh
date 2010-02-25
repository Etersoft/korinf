#!/bin/sh

get_name_from_fio()
{
# cut failed with names if field 2 is missed
#	echo "$@" | cut -d" " -f2
	echo $1 | awk '{print $2}'
}

# ФИО -> И Ф
get_fio_for_email()
{
	local FNAME="$(get_name_from_fio "$@")"
	local LNAME="$(echo "$@" | cut -d" " -f1)"
	local SNAME="$(echo "$@" | cut -d" " -f3)"
	[ -z "$FNAME" ] || echo -n "$FNAME "
	echo "$LNAME"
}


check()
{
	[ "$2" != "$3" ] && echo "FATAL with '$1': result '$3' do not match with '$2'" || echo "OK for '$1' with '$2'"
}

check_fio()
{
	check "$2" "$1" "$(get_fio_for_email "$2")"
}

check_fio "Пётр Иванов" "Иванов Пётр Петрович"
check_fio "Пётр Иванов" "Иванов  Пётр  Петрович"
check_fio "Пётр Иванов" "Иванов Пётр"
check_fio "Иванов" "Иванов"
