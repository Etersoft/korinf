#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

NAME=$(basename $0 .sh)

export KORINFMODULE=gpupdate

bash $(dirname $0)/../bin/korinf $NAME "$@"
