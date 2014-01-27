#!/bin/sh

# Function instrKRF() search string $2 in string $1.
# Return value - integer in [0..255]
# 0 - true
# NOT 0 - false
#

instrKRF()
{
	echo "$1" | grep -q "$2"
}


test_instr()
{
	local DIST="$1"
	if [ -z "$DIST" ]
	then
		DIST="XXX YYY ZZZ"
	fi
	
	echo "DIST : $DIST"
	
	if ! instrKRF "$DIST" "ArchLinux" && ! instrKRF "$DIST" "Gentoo"
	then
		echo "String NOT include ArchLinux or Gentoo"
	else
		echo "String include ArchLinux or Gentoo"
	fi
	echo
}


test_instr
test_instr "EEEGentooFGH"
test_instr "ABC EFG"
test_instr "VVV ArchLinux ZXC"
test_instr "ArchLinux ZXC Gentoo"
