#!/bin/sh
# ������� ������ �� ������ � ����� makeiso-sql.sh.nums
# FIXME: ���������� Network � SQL
# ���������� README � �������� � ������
#./prepare_release.sh

cd ../`dirname $0`
. makeiso/functions.sh

export PRODUCT=SQL
export CPRODUCT=sql
export WINENUMVERSION=1.0.10

build_packages
