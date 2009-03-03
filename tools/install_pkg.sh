#!/bin/sh

cd `dirname $0`/..

. functions/helpers.sh

# Нужно оформить в виде обычной команды по типу build_rpm

unset DISPLAY
#SOURCEPKGNAME=libe2fs-devel
#SOURCEPKGNAME=freeglut-devel
#ntfsprogs-devel
#SOURCEPKGNAME=docbook-utils

export REBUILDLIST=lists/rebuild.list.all
#export REBUILDLIST="FedoraCore/4 FedoraCore/5 FedoraCore/6 FedoraCore/7"
#export REBUILDLIST="SUSE/10 SUSE/10.1 SUSE/10.3"
#export REBUILDLIST="Debian/4.0 Debian/3.1"
#export REBUILDLIST="Ubuntu/8.04 Ubuntu/8.10"


SUDO="sudo"
if [ $UID = "0" ]; then
	SUDO=""
fi

end_umount()
{
	$SUDO umount $TESTDIR && echo "Unmounted $SYS" #|| exit 1
}

exit_handler()
{
    local rc=$?
    trap - EXIT
    warning "Interrupted"
    end_umount
    exit $rc
}
trap exit_handler EXIT HUP INT QUIT PIPE TERM


run_command()
{
	local SYS=$1
	local COMMAND=$2
	export TMPDIR=/tmp
	TESTDIR=`mktemp -d /tmp/autobuild/chroot-$USER-XXXXXX`
	echo Mount $SYS from local...
	$SUDO mount $LOCALLINUXFARM/$SYS $TESTDIR --bind || return 0
	#echo Chrooting...
	export HOSTNAME=$SYS
	export PS1="[\u@$SYS \W]\$"

# Package names
#export VENDOR=`ROOTDIR=$LINUXHOST/$SYS distr_vendor -s`
export DISTRVERSION=`ROOTDIR=$LOCALLINUXFARM/$SYS distr_vendor -v`
#PACKAGING=`ROOTDIR=$LINUXHOST/$SYS distr_vendor -p`

LIST=`ROOTDIR=$LOCALLINUXFARM/$SYS print_pkgrepl_list`
#LIST="libreadline5-dev"


#LIST="$PKGREPLBASE/pkgrepl.$VENDOR.$DISTRVERSION $PKGREPLBASE/pkgrepl.$VENDOR"
#[ "$VENDOR" != "alt" ] && LIST="$LIST $PKGREPLBASE/pkgrepl.$PACKAGING"
echo $LIST

#tolocal_anyrepl $SOURCEPKGNAME $LIST || TARGETPKGNAME=$SOURCEPKGNAME

# нужно уметь получить buildreqs из спека
#print_target_buildreq

#echo $PKGNAME
#exit 1

# Script for run internal chroot
touch $LOCALLINUXFARM/$SYS/tmp/run_sc.sh || exit 1
cat >$LOCALLINUXFARM/$SYS/tmp/run_sc.sh <<EOF
#!/bin/sh
export LC_MESSAGES=C
PACKAGING=\$(distr_vendor -p)
DISTR=\$(distr_vendor)
NEEDG=
# Note: PKGNAME from here!
echo Distr: \$DISTR, install $PKGNAME
case \$PACKAGING in
	"rpm")
		# FIXME
		rpm -q $PKGNAME || NEEDG=1
		;;
	*)
		NEEDG=1
		;;
esac

if [ -n "\$NEEDG" ] ; then
case \$DISTR in
	"RedHat/9"|"Mandriva/2005"|"Mandriva/2006"|"Ubuntu/5.10")
		echo "Skipped, too old"
		NEEDG=
		;;
	*)
		NEEDG=1
		;;
esac
fi

#PKGNAME=`rpmgp -l $SRCRPM`
PKGNAME="cmake"
PKGNAME="expat-devel"

DISTRVENDOR=\$(distr_vendor -d)
echo "Distr: \$DISTRVENDOR, install '\$PKGNAME' NEEDG=\$NEEDG"
if [ -n "\$NEEDG" ] ; then
#apt-get remove libicu28-dev
case \$DISTRVENDOR in
	"ALTLinux"|"Ubuntu"|"Debian"|"PCLinux")
		apt-get -y --force-yes install \$PKGNAME || exit 1
		#echo
		;;
	"LinuxXP"|"Fedora"|"ASPLinux"|"CentOS"|"RHEL"|"Scientific")
		yum -y install \$PKGNAME || exit 1
		;;
	"Mandriva")
		urpmi -q \$PKGNAME
		;;
	"SUSE"|"NLD")
		echo "?? yast -i \$PKGNAME?" || exit 1
		yast2 -i \$PKGNAME
		;;
	*)
		echo "Skipping \$DISTRVENDOR: \$(distr_vendor)"
		;;
esac
fi
EOF
	COMMAND='sh /tmp/run_sc.sh'
	#COMMAND='rpm -qa | grep wine'
	$SUDO chroot $TESTDIR su -c "mount /proc" || return 1
	$SUDO chroot $TESTDIR su -c "$COMMAND" || return 1
	$SUDO chroot $TESTDIR su -c "umount /proc" || return 1
	end_umount
	rmdir $TESTDIR
}



[ -f "$REBUILDLIST" ] && CMDRE=`cat $REBUILDLIST | grep -v "^#"` || CMDRE=$REBUILDLIST
[ -z "$CMDRE" ] && fatal "build list is empty"

for dist in $CMDRE ; do
	dist_ver=`echo $dist | sed -e "s|.*/||g"`
	dist_name=`echo $dist | sed -e "s|/.*||g"`
	[ -z "$dist_name" ] && fatal "Empty dist_name for $dist"
	echo
	#echo $dist
	echo "Build $BUILDSRPM in chrooted system for $dist"

	#cp -f $BUILDSRPM $BUILDERHOME/tmp/$BUILDNAME.src.rpm || { warning "Can't copy src.rpm" ; return 1 ; }

	run_command $dist 
done

# disable trap before exit
trap - EXIT
