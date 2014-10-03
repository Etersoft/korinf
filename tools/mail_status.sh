#!/bin/sh

cd ~/Projects/git/korinf/bin-wine || exit

print_report()
{
    ./wine-vanilla.sh -c all last
    ./wine-public.sh -c all last
    ./wine-etersoft.sh -c all last
    ./wine-gecko.sh -c all last
    ./wine-mono.sh -c all last
}

print_report | mutt -s "Korinf status report" lav@etersoft.ru
