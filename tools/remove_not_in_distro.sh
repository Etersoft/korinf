#!/bin/sh

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

# Etalon path
#PATHTO=/var/ftp/pub/Etersoft/WINE@Etersoft/2.0.2
PART=
if [ -n "$2" ] ; then
    PART="/$1"
    shift
fi

PATHTO="$1"
PATHTOD=$(echo "$PATHTO" | sed -e "s|/pvt/|/pub/|" | sed -e "s|-eter[0-9]*||")
PSD="$PATHTO$PART"

#if [ ! -s "$PATHTOD/distro.list" ] ; then
#    echo "Can't locate $PATHTOD/distro.list"
#    exit
#fi

DL=$(get_distro_list $PATHTOD 2>/dev/null) || DL=$(get_distro_list $(get_target_list "ALL")) || exit

[ -n "$DL" ] || exit

if [ "$PART" = "/--list" ] ; then
    echo "$DL"
    exit
fi

in_dl()
{
	echo "$DL" | grep -q "^$1\$"
}

print_dirs()
{
	local i
	for i in $PSD ; do
		find $i -mindepth 2 -maxdepth 2  -type d -printf "%P\n" | grep -v x86_64
		find $i/x86_64 -mindepth 2 -maxdepth 2 -type d -printf "x86_64/%P\n"
	done
}

echo "Check in $PSD ..."
for i in $(print_dirs); do
	#in_dl $i && echo "INDL $i" || echo "not in DL $i"
	in_dl $i && continue
	echo "Removing $PSD/$i ..."
	rm -rfv $PSD/$i
done

echo "Removing empty dirs"
# fixme: --days is unneeded in future fixed version
eterremove remove --days 1000 --notest empty $PSD
eterremove remove --days 1000 --notest empty $PSD
