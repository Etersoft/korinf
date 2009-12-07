#!/bin/sh

#script that checks built packages for our products
#usage: ./check_products.sh SYSLIST CHECKPROJECT

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common


define_paths()
{
# �������� � KORINFROOTDIR ��������, ���������� ��������� �������
	find $1 -name bin-\* -print | grep -v old
}

define_components()
{
# �������� ����� .sh � $PATHTOSCRIPT, �������� ����� foo-all.sh, release-check, cabextract
# FIXME: ������ �������� dkms-* ��� ��-�������: ��������, ����� ���������� ADDITIONALGREPS, ����������� �� �������������
	DIRCONTENTS=`find $1 -maxdepth 1 -print | grep ".sh" | grep -v all | grep -v release-check`
	#| grep -v cabextract
	#| grep -v dkms-aksparlnx
	#$ADDITIONALGREPS
	for i in $DIRCONTENTS ; do
		basename $i .sh
	done
}

grep_script()
{
	#FIXME: Highlight this with another color
	echo "Checking $1 for $2"
# ��������� ��������� ������� � ���������� -c, ������� ������, ���������� ��������� �� ���������� ��� ����������� �������
	$PATHTOSCRIPT/$1.sh -c $2 | grep -e OBS -e MISSED | grep -v Legend | grep -v link | grep -v error || echo "Everything is built"
}


#start script
KORINFROOTDIR="../"
CHECKSYSLIST=$1
CHECKPROJECT=$2

if [ -z $CHECKPROJECT ] ; then
    PRODUCTPATHS=`define_paths $KORINFROOTDIR`
else
    PRODUCTPATHS=$KORINFROOTDIR/bin-${CHECKPROJECT}
fi

echo PRODUCTPATHS=$PRODUCTPATHS

for PATHTOSCRIPT in $PRODUCTPATHS ; do
	COMPONENTS=`define_components $PATHTOSCRIPT`
	for i in $COMPONENTS ; do
		grep_script $i $CHECKSYSLIST
		echo
	done
done