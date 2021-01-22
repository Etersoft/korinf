#!/usr/bin/env bash

SALESDIR="/srv/builder/sales"

function showdoc {
    echo -e "-h\tshow this page"
    echo -e "-c\tcount failed tasks sorted by product"
    echo -e "-u\tnuiq result by product"
}

function count_failed(){
    echo -e "PRODUCT:\tCOUNT"
    PRODUCTLIST=$(grep DOWNLOADDIR $SALESDIR/*.failed |awk -F: '{print $2}'| sort | uniq | awk -F= '{print $2}')
    for i in $PRODUCTLIST
    do
        pattern="DOWNLOADDIR="$i
        count=$(grep $pattern $SALESDIR/*.failed | wc -l)
        echo -e $i" :\t" $count
    done
}

function dist_count(){
    distname=$1
    sh ./failed_reports.sh -A1 -B1| grep $distname | wc -l
}

[ $# == 0 ] && grep DOWNLOADDIR $SALESDIR/*.failed |awk -F: '{print $2}' | sort
[ "$1" == "-h" ] && showdoc
[ "$1" == "-c" ] && count_failed
[ "$1" == "-u" ] && grep DOWNLOADDIR $SALESDIR/*.failed |awk -F: '{print $2}'| sort | uniq
[ "$1" == "-t" ] && testing "Windows/ALL"
