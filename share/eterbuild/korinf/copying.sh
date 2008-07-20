#!/bin/sh
# 2005, 2006, 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License


# Подготовка к копированию, общая для всех систем
prepare_copying()
{
	# Expand file lists, remove old packages
	if [ -n "$MAINFILES" ] ; then
		mkdir -p $DESTDIR || fatal "Can't create $DESTDIR"
		echo "Removing old '$MAINFILES' from $DESTDIR..."
		pushd $DESTDIR >/dev/null || return 1
		rm -fv $EXPMAINFILES
		popd
	fi
	if [ -n "$EXTRAFILES" ] ; then
		mkdir -p $DESTDIR/extra || fatal "Can't create $DESTDIR/extra"
		echo "Removing old '$EXTRAFILES' from $DESTDIR/extra..."
		pushd $DESTDIR/extra >/dev/null || return 1
		rm -fv $EXPEXTRAFILES
		popd
	fi

}


copying_packages()
{
	RC=0
	prepare_copying

	echo "Copying built packages to $DESTDIR (cd to $BUILTRPM)..."
	pushd $BUILTRPM >/dev/null

	# Don't public debug packages now (it may contain source files)
	rm -f *${BUILDNAME}-debuginfo* *${BUILDNAME}-debug-*

	if [ -n "$MAINFILES" ] ; then
		cp -v $EXPMAINFILES $DESTDIR/ || { warning "Cannot copy new packages $EXPMAINFILES" ; RC=1 ; }
	fi
	if [ -n "$EXTRAFILES" ] ; then
		cp -v $EXPEXTRAFILES $DESTDIR/extra/ || { warning "Cannot copy extra packages $EXPEXTRAFILES" ; RC=1 ; }
	fi

	popd
	#pushd $DESTDIR
	# FIXME
	chmod ug+rw $DESTDIR/* -R 2>/dev/null
	chmod o+r $DESTDIR/* -R 2>/dev/null
	return $RC
}
