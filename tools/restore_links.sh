#!/bin/sh

cd `dirname $0`/..

. functions/helpers.sh

# Original path
PATHTO=$WINEPUB_PATH/$WINENUMVERSION/WINE
#PATHNEW=$WINEPUB_PATH-1.0.7/fonts
#PATHNEW=$WINEPUB_PATH/../CIFS@Etersoft/4.0.0
#PATHNEW=$WINEPUB_PATH/1.0.9/fonts
#PATHNEW=$WINEETER_PATH/current/WINE-SQL
PATHNEW=$WINEPUB_PATH/../PostgreSQL/8.2

for i in $DISTR_LIST; do
	LI=
	if [ -L $PATHTO/$i ] ; then
		LI=`readlink $PATHTO/$i | sed -e "s|\.\./||g;s|/| |g"`
		RL=`readlink $PATHTO/$i`
		if [ ! -e $PATHNEW/$i ] ; then
			mkdir -p `dirname $PATHNEW/$i`
			ln -s $RL $PATHNEW/$i
		fi
	fi
	#FILENAME=$(ls -1 $PATHTO/$i/wine* 2>/dev/null | head -n1)
	echo "i: $i LI: $LI RL: `readlink $PATHTO/$i` -- `dirname $PATHNEW/$i`"
	
	#echo $FILENAME
	#test -f "$FILENAME" || LI=" (на $DATE ещё не готово)"
	#echo ". @${i/\// }$LI|$WINESITE/$i@"

done
