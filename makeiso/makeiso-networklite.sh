#!/bin/sh
# ������� ������ �� ������ � ����� makeiso-sql.sh.nums
# FIXME: ���������� Network � SQL
# ���������� README � �������� � ������
#./prepare_release.sh

cd ../`dirname $0`
. makeiso/functions.sh

export PRODUCT=NetworkLite
export WINENUMVERSION=1.0.10
export CPRODUCT=networklite

build_packages
