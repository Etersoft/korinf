#!/bin/sh
# Копировать README и лицензию в корень

cd ../`dirname $0`

. /etc/rpm/etersoft-build-functions

# For compatibility: If not included jet
#if [ -z "$CHROOTDIR" ] ; then
#	. functions/config.in || fatal "Can't locate config.in"
#fi

DATESTAMP=`date "+%Y%m%d"`

# Path to hold ISOs
PATHTOFTP=/var/local/iso
WINENUMVERSION=1.0.6
PGVERSION=8.3

SOURCE_PATH=/var/ftp/pub/Etersoft
SELTAPUB_PATH=$SOURCE_PATH/SELTA@Etersoft/$WINENUMVERSION
PGPUB_PATH=$SOURCE_PATH/PostgreSQL/$PGVERSION

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
	echo "Creating ISO in $PATHTOFTP/$FILENAME"
	mkisofs -v -V "SELTA@Etersoft $WINENUMVERSION" \
	-p "Alexander, $DATESTAMP" \
	-m "*MD5SUM*" \
	-m "*distro.list*" \
	-m "*/log/*" \
	-publisher "Etersoft, selta@etersoft.ru" \
	-sysid LINUX -o $PATHTOFTP/$FILENAME.building  -r -J -graft-points -quiet -f \
	SELTA@Etersoft=$SELTAPUB_PATH PostgreSQL=$PGPUB_PATH \
	Updates.html=$SELTAPUB_PATH/docs/Updates.htm \
	README.html=$SELTAPUB_PATH/docs/README.html \
	autorun.inf=$SELTAPUB_PATH/docs/autorun.inf \
	docs=$SELTAPUB_PATH/docs \
	|| exit 1
	mv -f $PATHTOFTP/$FILENAME.building $PATHTOFTP/$FILENAME

# do not needed
#	autorun.inf=$SELTAPUB_PATH/docs/autorun.inf

}

FILENAME=selta-$DATESTAMP.iso
#sed -e "s/XXXX-XXXX/$ETERREGNUM/g" <$WINEETER_PATH$ALPHAP/docs/README_$PRODUCTNAME.html >$WINEETER_PATH$ALPHAP/README.html || exit 1
#sed -e "s/XXXX-XXXX/$ETERREGNUM/g" <$WINEETER_PATH$ALPHAP/docs/license_$PRODUCTBASE.html >$WINEETER_PATH$ALPHAP/license.html || exit 1

makeiso || exit 1
