#!/bin/sh

. /etc/rpm/etersoft-build-functions

# set TESTBUILDDIST to bsd/gen/alt for debug

# For compatibility: If not included jet
if [ -z "$CHROOTDIR" ] ; then
	. /srv/yurifil/Projects/korinf/etc/korinf
#functions/config.in || fatal "Can't locate config.in"
fi

check_key || exit 1

DATESTAMP=`date "+%H%M"`

# Path to hold ISOs
PATHTOFTP=/var/local/iso
LOCALWINEPUB_PATH=/var/local/WINE@Etersoft

FILERES=`dirname $0`/makeiso/tempres
FILEREP=`dirname $0`/makeiso/filerep

exit_handler()
{
    local rc=$?
    trap - EXIT
    echo "Catch interrupt"
    kill `jobs -p`
    rm -f $FILERES
    exit $rc
}

# �������� � ����������� �� ��� ������� FTP
# ���� ���������, ����� ����������� �� ��������� �����

makeiso()
{
	#LANG=C ls -lR $WINE_PATH/ >$WINE_PATH/MANIFEST
	echo "Creating ISO in $PATHTOFTP/$FILENAME"
	mkisofs -V "WINE@Etersoft $WINENUMVERSION $PRODUCT" \
	-p "Plikus Alexander, $DATESTAMP" \
	-m "*update-from*" \
	-m "*MD5SUM*" \
	-m "*/log/*" \
	-m "README_*" -m "license_*" \
	-m "$WINEETER_PATH$ALPHAP/source*" \
	-m "*Special*" \
	-publisher "Etersoft, wine@etersoft.ru" \
	-sysid LINUX -o $PATHTOFTP/$FILENAME.building  -r -J -graft-points -quiet \
	-f $WINEPUB_PATH$ALPHA $WINEETER_PATH$ALPHAP || exit 1
	mv -f $PATHTOFTP/$FILENAME.building $PATHTOFTP/$FILENAME
#	-m "*_Network*" -m "network_*" \
#	-m "*_Local*" -m "local_*" \

}

build_packages()
{
	PRODUCTBASE=`echo $PRODUCT | tr '[:upper:]' '[:lower:]'`

#trap exit_handler EXIT HUP INT QUIT PIPE TERM
for i in `cat makeiso/$0.nums` ; do
	echo
	echo
	echo "Build $PRODUCTBASE iso"
	FILENAME=wine$PRODUCTBASE.iso
	if [ -f $PATHTOFTP/$FILENAME ] ; then
		echo "Already exists: $FILENAME. Skipping..."
		continue
	fi
	# echo "Running all builds ..."
	>$FILERES

	if [ -n "$TESTBUILDDIST" ] ; then
		echo "Test mode: Skip ISO image build"
		exit 1
	fi

	ALPHA=/$WINENUMVERSION
	ALPHAP=/$WINENUMVERSION/WINE-$PRODUCT

	makeiso || exit 1
	echo "Built $ETERREGNUM at `date`" >> $FILEREP
done
#trap - EXIT
}
