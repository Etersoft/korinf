#!/bin/sh

# Копируем наши пакеты в репозиторий LINUX@Etersoft

cd $(dirname $0)/.. || exit

# wine
WINEVER=2.1
./publish_wine_to_our_distro.sh $WINEVER
./publish_wine_to_our_distro.sh $WINEVER-testing

# other products
./publish_other_to_our_distro.sh stable
./publish_other_to_our_distro.sh testing
