#!/bin/bash

# function for showing help
function showdoc()
{
	echo "Exec with LIST:"
	echo "$0 PRODUCTNAME \$DISTLIST "
	echo " "
	echo "Create LIST of distros for rebuild: DISTLIST=\"SUSE/**.* ALTLinux/** ... \""
	echo "PRODUCTNAME : vanilla, public, etersoft, local, network, sql"
	echo "Attention: rebuilds with -F parameter"
}

# set profuct exec file
function setproductpath()
{
	case "$1" in
		vanilla)
			PATHTOPRODUCT="/srv/builder/Projects/korinf/bin-wine/wine-vanilla.sh"
			;;
		public)
			PATHTOPRODUCT="/srv/builder/Projects/korinf/bin-wine/wine-public.sh"
			;;
		etersoft)
			PATHTOPRODUCT="/srv/builder/Projects/korinf/bin-wine/wine-etersoft.sh"
			;;
		local)
			PATHTOPRODUCT="/srv/builder/Projects/korinf/bin-wine/wine-etersoft-local.sh"
			;;
		network)
			PATHTOPRODUCT="/srv/builder/Projects/korinf/bin-wine/wine-etersoft-network.sh"
			;;
		sql)
			PATHTOPRODUCT="/srv/builder/Projects/korinf/bin-wine/wine-etersoft-sql.sh"
			;;
		*)
			showdoc
			exit 1
			;;
	esac
}

#all rebuid loop
function buildloop()
{
	for i in $1
	do
		echo " $PATHTOPRODUCT building $i"
		$PATHTOPRODUCT $i -F 
	done
}

function notmatcharg()
{
	showdoc
	exit 1
}

[ $# -ne 2 ] && notmatcharg 
setproductpath "$1"
buildloop "$2"

