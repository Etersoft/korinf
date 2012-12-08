#!/bin/sh

# Копируем наши пакеты в репозиторий LINUX@Etersoft

cd $(dirname $0)/.. || exit

./publish_wine_to_our_distro.sh 2.0

# 1.0.12 conflicts with 2.0
#./publish_wine_to_our_distro.sh 1.0.12

./publish_wine_to_our_distro.sh 2.0-testing

./publish_other_to_our_distro.sh stable

./publish_other_to_our_distro.sh testing
