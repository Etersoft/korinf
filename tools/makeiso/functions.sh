#!/bin/sh

. /etc/rpm/etersoft-build-functions

# set TESTBUILDDIST to bsd/gen/alt for debug

# For compatibility: If not included jet
if [ -z "$CHROOTDIR" ] ; then
	. functions/config.in || fatal "Can't locate config.in"
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

# Собирает и выкладывает на наш обычный FTP
# Надо исправить, чтобы выкладывала во временную копию
build_system()
{
	SYS=$1
	echo "Build $SYS on builder"
	BUSER=builder
	ALOGDIR=/home/builder/Projects/eterbuild/log/`date "+%Y%m%d"`
	export ALOGDIR
	ssh $BUSER@builder REBUILDLIST=lists/rebuild.list.$SYS ETERREGNUM=$ETERREGNUM PRODUCT=$PRODUCTBASE WINENUMVERSION=$WINENUMVERSION \
		/home/$BUSER/Projects/eterbuild/makeiso/build-wine-package.sh
	[ $? != 0 ] && { echo "FAIL with $SYS" >>$FILERES ; tail -n 3 $ALOGDIR/autobuild.report.log ; }
	# </dev/stdin >/dev/stdout
}

makeiso()
{
	#LANG=C ls -lR $WINE_PATH/ >$WINE_PATH/MANIFEST
	echo "Creating ISO in $PATHTOFTP/$FILENAME"
	mkisofs -V "WINE@Etersoft $WINENUMVERSION $PRODUCTNAME" \
	-p "Plikus Alexander, $DATESTAMP" \
	-m "*update-from*" \
	-m "*MD5SUM*" \
	-m "*/log/*" \
	-m "README_*" -m "license_*" \
	-m "$WINEETER_PATH$ALPHAP/source*" \
	-m "*Special*" \
	-publisher "Etersoft, wine@etersoft.ru" \
	-sysid LINUX -o $PATHTOFTP/$FILENAME.building  -r -J -graft-points -quiet \
	-f $LOCALWINEPUB_PATH$ALPHA $WINEETER_PATH$ALPHAP || exit 1
	mv -f $PATHTOFTP/$FILENAME.building $PATHTOFTP/$FILENAME
#	-m "*_Network*" -m "network_*" \
#	-m "*_Local*" -m "local_*" \

}

build_packages()
{
	PRODUCTBASE=`echo $PRODUCTNAME | tr '[:upper:]' '[:lower:]'`

#trap exit_handler EXIT HUP INT QUIT PIPE TERM
for i in `cat makeiso/$0.nums` ; do
	ETERREGNUM=$i
	echo
	echo
	echo "Build with $ETERREGNUM number"
	FILENAME=wine$PRODUCTBASE-$ETERREGNUM.iso
	if [ -f $PATHTOFTP/$FILENAME ] ; then
		echo "Already exists: $FILENAME. Skipping..."
		continue
	fi
	# echo "Running all builds ..."
	>$FILERES
	if [ -z "$TESTBUILDDIST" ] ; then
		build_system bsd &
		build_system alt &
		build_system gen &
#		echo
	else
		build_system $TESTBUILDDIST
#		build_system alt
#		build_system gen
	fi
	echo "Wait for finishing..."
	wait
	if grep FAIL $FILERES ; then
		#cat $FILERES
		exit 1
	fi

	if [ -n "$TESTBUILDDIST" ] ; then
		echo "Test mode: Skip ISO image build"
		exit 1
	fi

	ALPHA=/$WINENUMVERSION
	ALPHAP=-disk/$WINENUMVERSION/$PRODUCTBASE
	sed -e "s/XXXX-XXXX/$ETERREGNUM/g" <$WINEETER_PATH$ALPHAP/docs/README_$PRODUCTNAME.html >$WINEETER_PATH$ALPHAP/README.html || exit 1
	sed -e "s/XXXX-XXXX/$ETERREGNUM/g" <$WINEETER_PATH$ALPHAP/docs/license_$PRODUCTBASE.html >$WINEETER_PATH$ALPHAP/license.html || exit 1

	makeiso || exit 1
	echo "Built $ETERREGNUM at `date`" >> $FILEREP
done
#trap - EXIT
}
