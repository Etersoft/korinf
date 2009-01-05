#!/bin/sh
# Make deltas
# 2006 (c) Etersoft www.etersoft.ru
# Public domain
# Run without params for all prev. versions

. /etc/rpm/etersoft-build-functions

. ./config.in

#export ALPHA=Alpha

LISTOLDVER="0.9 1.0.0 1.0.1 1.0.2"
if [ -z "$1" ] ; then
	for i in $LISTOLDVER ; do
		$0 $i
	done
	exit 0
fi
OLDVER=$1

exit_handler()
{
    local rc=$?
    trap - EXIT
    #rm -r "$WTMP"
    exit $rc
}

#trap exit_handler EXIT HUP INT QUIT PIPE TERM

echo
echo -n "Product: $WINEVERSION. Check for date `date`"
echo

ALPHA=-$WINENUMVERSION
WINEVER="200[0-9]*"
PATHTO=$WINEPUB_PATH$ALPHA/WINE

UPDATENAME=update-from-$OLDVER
PATHTOOLD=$WINEPUB_PATH-$OLDVER/WINE
PATHTOUPDATE=$PATHTO-$UPDATENAME
echo
echo "Make deltarpm in $PATHTO"

for i in $DISTR_LIST ; do
	#NAME=$i
	echo "==== For $i"
	WTMP=`mktemp -t -d make_wine.XXXXXX` || fatal "tmp creating error"
	mkdir -p $WTMP
	cat <<EOF >$WTMP/applydeltarpm.sh
#!/bin/sh
EOF
	if [ -L $PATHTO/$i ] ; then
		LL=`readlink $PATHTO/$i`
		echo "Read link to $LL"
		mkdir -p `dirname $PATHTOUPDATE/$i` && ln -s $LL $PATHTOUPDATE/$i
		continue
	fi
	#echo "##### $FILENAMELIST"
	for fnte in "wine[-_]${WINEVER}" "libwine[-_]${WINEVER}" ; do
		ISREADY=
		fn=$(echo $PATHTO/$i/${fnte}*.rpm)
		if [ -f "$fn" ] ; then
			#echo "-------- $fn"
			NAME=`basename "$fn"`
			fnold=$(echo $PATHTOOLD/$i/${fnte}*.rpm)
			if [ -f "$fnold" ] ; then
				deltar=`basename ${fn/.rpm/.deltarpm}`
				echo " # make $deltar for $NAME from `basename $fnold`"
				makedeltarpm $fnold $fn $WTMP/$deltar || fatal "Can't do delta"
				ISREADY="yes"
				cat <<EOF >>$WTMP/applydeltarpm.sh
# See deltarpm package in extra for add. info
echo "Creating new package $NAME..."
./applydeltarpm -p -r `basename $fnold` $deltar $NAME
EOF
			fi
		fi
		#ls -l $WTMP
	done
	if [ -n "$ISREADY" ] ; then
		NAME_DISTR=`echo $i | sed -e "s|^./||"`
		NAME_DISTR=`echo ${NAME_DISTR/\//-} | tr [A-Z] [a-z]`
		FULL_ARCH=wine-$WINENUMVERSION-$NAME_DISTR-$UPDATENAME
		#ETER_ARCH=wine-eter-$VERSION-$NAME_DISTR
		mkdir -p $PATHTOUPDATE/$i/
		rm -f $PATHTOUPDATE/$i/*.run
		cat <<EOF >>$WTMP/applydeltarpm.sh
rm -f ./applydeltarpm
rm -f ./applydeltarpm.sh
rm -f wine-fonts-ttf*
echo "DONE"
EOF
		chmod u+x $WTMP/applydeltarpm.sh
		# Add our deltarpm to archive
		DELTARPMNAME=$(echo $PATHTO/$i/extra/deltarpm-[0-9]*)
		test -f $DELTARPMNAME || fatal "$DELTARPMNAME is not found"
		cd $WTMP 
			cat $DELTARPMNAME | rpm2cpio | cpio -i --make-directories "*applydeltarpm"
			# remove subdirs
			#find -depth -mindepth 2 -print0 -type f | xargs -0 -n1 -I'{}' mv '{}' ./
			find -depth -type f -print0 | xargs -0 -n1 -I'{}' mv '{}' ./
			#find -depth -mindepth 2 -print0 -type d | xargs -0 -n1 rmdir
			find -depth -type d -print0 | xargs -0 -n1 rmdir
		cd -
		test -f $WTMP/applydeltarpm || fatal "applydelta is not found"

		makeself.sh --bzip2 --current --lsm $PATHTO/../docs/wine@etersoft.lsm $WTMP/ $PATHTOUPDATE/$i/$FULL_ARCH.run \
			"WINE@Etersoft $WINEVERSION ..." ./applydeltarpm.sh  || fatal "Can't make run-file"
	fi
	rm $WTMP/*
	rmdir $WTMP
done

