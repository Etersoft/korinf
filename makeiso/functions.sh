#!/bin/sh

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

check_key || exit 1

DATESTAMP=`date "+%Y%m%d"`

# Path to hold ISOs
PATHTOFTP=/var/local/iso
WINENUMVERSION=$(readlink $WINEPUB_PATH/last)
WRITER=$EMAIL

test -n "$WRITER" || fatal "WRITER is empty"
test -n "$WINENUMVERSION" || fatal "WINENUMVERSION is empty"

FILERES=`dirname $0`/tempres
FILEREP=`dirname $0`/filerep

exit_handler()
{
    local rc=$?
    trap - EXIT
    echo "Catch interrupt"
    kill `jobs -p`
    rm -f $FILERES
    exit $rc
}

makeiso()
{
       PRODUCT=$1
       PRODUCTBASE=`echo $PRODUCT | tr '[:upper:]' '[:lower:]'`

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

       ALPHA=/$WINENUMVERSION
       ALPHAP=/$WINENUMVERSION/WINE-$PRODUCT

	echo "Creating ISO in $PATHTOFTP/$FILENAME"
	mkisofs -v -V "WINE@Etersoft $WINENUMVERSION $PRODUCT" \
	-p "$WRITER, $DATESTAMP" \
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
	WINE=$WINEPUB_PATH$ALPHA/HASP \
	$WINEPUB_PATH$ALPHA \
	$WINEETER_PATH$ALPHA/{autorun*,docs/license_${PRODUCTBASE}*.html} \
	docs/=$WINEETER_PATH$ALPHA/docs/{README_$PRODUCT.html,${PRODUCTBASE}_manual.html,install.html,redist.html,images/etersoft.ico} \
	docs/images/=$WINEETER_PATH$ALPHA/docs/images/etersoft.ico \
	README.html=$WINEETER_PATH$ALPHA/docs/README_$PRODUCT.html \
	|| exit 1
	mv -f $PATHTOFTP/$FILENAME.building $PATHTOFTP/$FILENAME
#	-m "*_Network*" -m "network_*" \
#	-m "*_Local*" -m "local_*" \

}

