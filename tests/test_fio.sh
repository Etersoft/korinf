#!/bin/sh

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod messages/fio

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
check_fio "" ""
check_fio "Зелёная ООО" 'ООО "Зелёная петрушка"'


check_dear()
{
	check "$2" "$1" "$(get_dear_from_fio "$2" "$3")"
}

check_dear "Пётр Петрович" "Иванов Пётр Петрович" "покупатель"
check_dear "Пётр Петрович" "Иванов  Пётр  Петрович" "покупатель"
check_dear "Пётр" "Иванов Пётр" "покупатель"
check_dear "Иванов" "Иванов" "покупатель"
check_dear "покупатель" "" "покупатель"
check_dear "" "" ""
check_dear "Зелёная петрушка" 'ООО "Зелёная петрушка"' "покупатель"

