#!/bin/sh
# ������� ������ �� ������ � ����� makeiso-sql.sh.nums
# FIXME: ���������� Network � SQL
# ���������� README � �������� � ������
#./prepare_release.sh

cd ../`dirname $0`
. makeiso/functions.sh

export PRODUCTNAME=SQL
export WINENUMVERSION=1.0.9

build_packages
