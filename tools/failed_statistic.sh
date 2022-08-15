#!/bin/sh

SALES="../../../sales"
FILES=$SALES"/*.failed"

function showhelp(){
	echo "Usage:"
	echo "-d : distributive statistic"
	echo "-d DIST: certain distributive statistic"
	echo "-p : product statistic"
}

function byproduct(){
  ALLPRODUCTS=$(grep PRODUCT $FILES | awk -F'PRODUCT=' '{ print $2}' | awk '{ print $1 }' | sed -E 's/"//g' | sort | uniq)
  
  function showdist(){
  	grep DIST $(grep "$1" $FILES -l) | awk -F'DIST=' '{ print $2 }' | sed 's/"//g' | sort | uniq -c | sort -nr
  }
  
  for i in $ALLPRODUCTS
  do
  	echo $i":"
  	showdist $i
  done
}

function bydist(){
  ALLDIST=$(grep DIST $FILES | awk -F'DIST=' '{ print $2}' | awk '{ print $1 }' | sed -E 's/"//g' | sort | uniq)

  function showproduct(){
  	grep PRODUCT $(grep "$1" $FILES -l) | awk -F'PRODUCT=' '{ print $2 }' | awk '{ print $1 }' | sed 's/"//g' | sort | uniq -c | sort -nr
  }

  function showcertaindist(){
	FILELIST=$( grep "$1" $FILES -l)
	for file in $FILELIST
	do
		echo -e '\n'$file | sed 's/^.*sales\///'
		awk -F'PRODUCT=' '/PRODUCT/ {print $2 }' $file
		tail -n 1 $file
	done
  }

  if [ $# -gt 1 ]
  then
    	echo $@":"
    	showcertaindist "$@"
  else
	for i in $ALLDIST
	do
	  echo $i":"
	  showproduct $i
	done
  fi
}

case "$1" in
	-d)
	  bydist "$2"
	;;
	-p)
	  byproduct
	;;
	*)
	  showhelp 
	;;
esac


