#!/bin/sh

DESTPATH=`pwd`
rpm -i $1-[0-9]*.src.rpm

cd ~/RPM/SPECS
rpmbs -z $1.spec
cd ../SRPMS
cp $1-[0-9]*.src.rpm $DESTPATH/
