#!/bin/sh

RPATH=$(dirname $0)
do_test()
{

SC=$RPATH/list_nfound_libs.sh

$SC stable
$SC testing
$SC 2.0.0
$SC school
$SC school-testing
$SC unstable

$SC last wine /var/ftp/pub/Etersoft/Wine-public
$SC last wine-vanilla /var/ftp/pub/Etersoft/Wine-vanilla

}

TFILE=~/tmp/nfound_test_file.out
touch "$TFILE"
EMAILS="lav@etersoft.ru alexalv@etersoft.ru baraka@etersoft.ru"
do_test >$TFILE.new 2>&1
DIFF=$(diff -u "$TFILE" "$TFILE.new")
if [ -n "$DIFF" ] ; then
	echo "$DIFF" | mutt $EMAILS -s "Changes in wine's not found libs"
fi
mv -f $TFILE.new $TFILE
