#!/bin/sh

for i in ALTLinux/Sisyphus ALTLinux/p10 AstraLinuxSE/1.7 AstraLinuxCE/2.12 RedOS/7.3 ; do
    ./wine-etersoft-bootstrap-new.sh x86_64/$i "$@"
done
