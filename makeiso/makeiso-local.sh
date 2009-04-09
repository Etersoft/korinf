#!/bin/sh
# Создаёт образы по списку в файле makeiso-sql.sh.nums
# FIXME: пропускать Network и SQL
# Копировать README и лицензию в корень
#./prepare_release.sh

cd ../`dirname $0`
. makeiso/functions.sh

export PRODUCT=Local
export CPRODUCT=local
export WINENUMVERSION=1.0.10

build_packages
