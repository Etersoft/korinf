#!/bin/sh
# ������� ������ �� ������ � ����� makeiso-sql.sh.nums
# FIXME: ���������� Network � SQL
# ���������� README � �������� � ������
#./prepare_release.sh

cd ../`dirname $0`
. makeiso/functions.sh

export PRODUCT=Network
export WINENUMVERSION=1.0.10
export CPRODUCT=network

build_packages
