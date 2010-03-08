#!/bin/sh
DIRNAME=$(pwd)
for i in cellar lav server builder builder64 ; do
	echo "Installing on $i..."
	ssh -t -Y $i $DIRNAME/install_wine.sh $@
done
