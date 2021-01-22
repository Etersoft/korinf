#!/usr/bin/env bash

SALESDIR="/srv/builder/sales"

tail -n 1 $SALESDIR/*.failed | grep "#" | awk -F\( '{ print $2 }' |sort | uniq
