#!/bin/sh
# 2005, 2006, 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# BUILD - root of current system
# BUILDERHOME - absolute path to user dir in current system

REMOTESSH=builder@solaris
REMOTEPATH=/export/home/builder/work

# PACKAGE
build_solaris()
{
	echo "Copying to Solaris"
	ssh $REMOTESSH "mkdir -p $REMOTEPATH" || { warning "Cannot create dir $REMOTEPATH" ; return 1 ; }
	scp  $KORINFDIR/korinf/remote-scripts/remote-solaris.sh $REMOTESSH:$REMOTEPATH/ || { warning "Cannot copy script" ; return 1 ; }
	echo "Building package with:"
	echo "PACKAGE:$PACKAGE WINENUMVERSION:$WINENUMVERSION ETERREGNUM:$ETERREGNUM SOURCEURL:$SOURCEURL"
	ssh $REMOTESSH "bash $REMOTEPATH/remote-solaris.sh $PACKAGE $WINENUMVERSION \"$ETERREGNUM\" $SOURCEURL" || { warning "Can't build" ; return 1 ; }
	true
}

copying_solaris()
{
	prepare_copying

	scp $REMOTESSH:/tmp/wine/ready/$PACKAGE[-_][0-9]*.pkg.gz $DESTDIR
	chmod g+rw -R $DESTDIR/* || true
}

cleaning_solaris()
{
	true
}
