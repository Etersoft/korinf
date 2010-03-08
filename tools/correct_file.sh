#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain
#

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

C_FILENAME=$1
REBUILDLIST="Mandriva/2008.1
Mandriva/2009.0
Mandriva/2009.1
Mandriva/2010.0
"

TESTDIR=/tmp/autobuild/testlog
mkdir -p $TESTDIR

set_rebuild_list
CMDRE=$(get_distro_list $REBUILDLIST)
[ -z "$CMDRE" ] && fatal "build list is empty"

for i in $CMDRE ; do
	BRPDIR=/usr/lib/rpm
        VENDOR=`dirname $i`
        #in some systems brp is placed in specific dirs:
	if [ $VENDOR = "LinuxXP" ] ; then
            BRPDIR=$BRPDIR/redhat
        fi
        if [ $VENDOR = "Mandriva" ] ; then
            BRPDIR=/usr/share/spec-helper
            #for Mandriva/2008.1 file is strip_files
            C_FILENAME=strip_and_check_elf_files
        fi

        C_FILE=$BRPDIR/$C_FILENAME

	echo Mount $i ...
        $SUDO mount $LOCALLINUXFARM/$i $TESTDIR --bind || exit 1
	echo Chrooting and executing...
        $SUDO chroot $TESTDIR su - -c "cp -f $C_FILE $C_FILE~"
        if [ $VENDOR = "Mandriva" ] ; then
	    $SUDO chroot $TESTDIR su - -c "sed -i '1i #!/bin/sh' $C_FILE"
	fi
        $SUDO chroot $TESTDIR su - -c "sed -i '2i #fix for bug 4778 @ bugs.etersoft.ru' $C_FILE"
        $SUDO chroot $TESTDIR su - -c "sed -i '3i exit 0;' $C_FILE"
	$SUDO umount $TESTDIR && echo "Unmount $i"
done

rm -rf $TESTDIR