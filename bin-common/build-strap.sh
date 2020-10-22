#!/bin/sh -x
# 2005, 2006, 2007, 2008, 2009 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

# install packages after build
export BOOTSTRAP=1

FIRST="$1"
shift

$(dirname $0)/../bin/korinf rpm-build-altlinux-compat "$FIRST" /var/ftp/pub/Etersoft/Sisyphus "$@"
# workaround
$(dirname $0)/../bin/korinf distro_info "$FIRST" /var/ftp/pub/Etersoft/Sisyphus "$@"
$(dirname $0)/../bin/korinf eepm "$FIRST" /var/ftp/pub/Etersoft/Sisyphus "$@"
