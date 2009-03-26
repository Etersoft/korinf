#!/bin/sh
FILENAME="/var/local/iso/wine*.iso"

for i in `echo $FILENAME | sort` ; do
	echo
	echo DVD burning
	echo Press Enter when ready for `basename $i` burn or type anything for skip
	read ent
	if [ -z "$ent" ] ; then
		echo "Disk injecting..."
		eject -t
		echo "Write starting..."
		growisofs -Z /dev/dvd=$i && mv $i $i.done
		eject
	fi
		echo ====================================================
done
