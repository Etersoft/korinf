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

# Собирает и выкладывает на наш обычный FTP
# Надо исправить, чтобы выкладывала во временную копию

makeiso()
{
	#LANG=C ls -lR $WINE_PATH/ >$WINE_PATH/MANIFEST
	echo "Creating ISO in $PATHTOFTP/$FILENAME"
	mkisofs -v -V "WINE@Etersoft $WINENUMVERSION $PRODUCT" \
	-p "Plikus Alexander, $DATESTAMP" \
	-m "*update-from*" \
	-m "*MD5SUM*" \
	-m "*/log/*" \
	-m "license_*" \
	-m "distro.list" \
	-m "$WINEETER_PATH$ALPHAP/source*" \
	-m "*Special*" \
	-publisher "Etersoft, wine@etersoft.ru" \
	-sysid LINUX -o $PATHTOFTP/$FILENAME.building  -r -J -f -quiet -graft-points \
	WINE=$WINEETER_PATH$ALPHAP \
	WINE=$WINEPUB_PATH$ALPHA/CIFS \
	$WINEPUB_PATH$ALPHA $WINEETER_PATH$ALPHA/{autorun*,docs/license_${CPRODUCT}*.html} \
	docs/=$WINEETER_PATH$ALPHA/docs/{README_$PRODUCT.html,${CPRODUCT}_manual.html,install.html,redist.html,images/etersoft.ico} \
	docs/images/=$WINEETER_PATH$ALPHA/docs/images/etersoft.ico \
	README.html=$WINEETER_PATH$ALPHA/docs/README_$PRODUCT.html \
	|| exit 1
	#$WINEETER_PATH$ALPHAP || exit 1
	mv -f $PATHTOFTP/$FILENAME.building $PATHTOFTP/$FILENAME
#	-m "*_Network*" -m "network_*" \
#	-m "*_Local*" -m "local_*" \

}

build_packages()
{
	PRODUCTBASE=`echo $PRODUCT | tr '[:upper:]' '[:lower:]'`

#trap exit_handler EXIT HUP INT QUIT PIPE TERM
	echo
	echo
	echo "Build $PRODUCTBASE iso"
	FILENAME=wine$PRODUCTBASE-$WINENUMVERSION.iso
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
#trap - EXIT
}
