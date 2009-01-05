#! /bin/sh

PATH_TO_WINE=/var/ftp/pub/Etersoft/WINE@Etersoft/1.0.9/WINE

N_ISO_PVT=`isoinfo -lR -i $1 | grep wine-etersoft-$2[-_] | wc -l`
N_SYSTEMS=`find $PATH_TO_WINE -mindepth 2 -maxdepth 2 -print | wc -l`

#let "N_SYSTEMS -= $2"
N_SYSTEMS=$(($N_SYSTEMS - $3))

#echo $N_ISO_PVT
#echo $N_SYSTEMS

if [[ $N_ISO_PVT -lt $N_SYSTEMS ]]
then echo "Check systems listed in $PATH_TO_WINE"
else echo "OK"
fi


