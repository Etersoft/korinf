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
WINENUMVERSION=1.0.8
PGVERSION=8.4

WRITER=$EMAIL
test -n "$WRITER" || fatal "WRITER is empty"
test -n "$WINENUMVERSION" || fatal "WINENUMVERSION is empty"

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
	-p "$WRITER, $DATESTAMP" \
	-m "*MD5SUM*" \
	-m "*/log/*" \
	-publisher "Etersoft, selta@etersoft.ru" \
	-sysid LINUX -o $PATHTOFTP/$FILENAME.building  -r -J -graft-points -quiet -f \
	SELTA@Etersoft=$SELTAPUB_PATH \
	PostgreSQL=$PGPUB_PATH \
	Updates.html=$SELTAPUB_PATH/docs/Updates.htm \
	README.html=$SELTAPUB_PATH/docs/README.html \
	autorun.inf=$SELTAPUB_PATH/docs/autorun.inf \
	docs=$SELTAPUB_PATH/docs \
	|| exit 1
	mv -f $PATHTOFTP/$FILENAME.building $PATHTOFTP/$FILENAME
}

FILENAME=selta-$DATESTAMP.iso

makeiso || exit 1
