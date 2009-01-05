#!/bin/sh
FILENAME="/var/ISO/wine*.iso"

for i in `echo $FILENAME | sort` ; do
	echo
	echo CD burning
	echo Press Enter when ready for `basename $i` burn or type anything for skip
	read ent
	if [ -z "$ent" ] ; then
		cdrecord speed=16 -v driveropts=burnfree -eject $i && mv $i $i.done
	fi
		echo ====================================================
done
