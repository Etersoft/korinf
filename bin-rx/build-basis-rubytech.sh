#! /usr/bin/sh

# ARGS:
# 1)    B_SCRIPT : Имя сборочного скрипта из ~/Projects/korinf/bin-rx 
#
# 2)    B_TARGET : Версия продукта: unstable -> stable [defalut] -> 1.*
#
# 3)      B_ARCH : Архитектура собираемого пакета: all, x86_64 [default], i586
#
#
# VARS:
# B_DISTR_LIST : Список дистирутивов предоставляемых в рамках продуктов Базиса+Рубитеха.
#                Дистрибутивы ALTLinux нам нужны для тестирования.
#
#
#
# Все новые пакеты сперва должны быть собраны в ALTLinux/Sisyphus либо x86_64/ALTLinux/Sisyphus вне данного скрипта


B_TARGET=stable
B_ARCH=x86_64
B_DISTR_LIST="ALTLinux/p11 ALTLinux/p10 RedOS/8.0 RedOS/7.3 AstraLinuxSE/1.8 AstraLinuxSE/1.7 ALTLinux/c10f2"
#B_DISTR_LIST="RedOS/8.0 RedOS/7.3"

show_help(){
	echo -e "\nArgs:\n"
	echo -e "    1) build script from ~/Projects/korinf/bin-rx"
	echo -e "    2) Target version: unstable, stable [default], 1.*, etc."
	echo -e "    3) Arch of builded package: all, x86_64 [default], i586\n"
}

[ "$#" -lt 1 ] && { echo -e "!!! Enter build script from ~/Projects/korinf/bin-rx"; exit 1; }
[ "$1" == "-h" ] && { show_help ; exit 0; }

B_SCRIPT="$1"

# TODO:
# - Добавить проверку на кол-во аргументов

[ -n "$2" ] && B_TARGET="$2"
#[ -n "$3" ] && B_ARCH="$3"

# TODO:
# - Реализовать сборки для обеих архитектору, кторая включается с помощью all

for dist in $B_DISTR_LIST
do
	#echo "./$B_SCRIPT $B_ARCH/$dist "$TARGET""
	./$B_SCRIPT $B_ARCH/$dist $2
done
