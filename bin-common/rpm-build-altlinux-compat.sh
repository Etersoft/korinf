#!/bin/sh
# 2005, 2006, 2007, 2008, 2009 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

# install packages after build
export BOOTSTRAP=1

$(dirname $0)/../bin/korinf rpm-build-altlinux-compat "$@" /var/ftp/pub/Etersoft/Sisyphus
