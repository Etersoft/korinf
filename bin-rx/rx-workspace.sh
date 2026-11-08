#!/bin/sh
# 2026 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3
#
# rx-workspace (eterbug #19932): only ALT Sisyphus x86_64 for now.
# The version is Workspace: sources and results in
# /var/ftp/pvt/Etersoft/RX@Etersoft/Workspace
#  ./rx-workspace.sh x86_64/ALTLinux/Sisyphus Workspace

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

SKIPBUILDLIST="FreeBSD OpenSolaris Windows"

NAME="rx-workspace"
# no rx-workspace package itself, only its subpackages (rx-workspace-client...);
# the first mask is the built check (get_bin_package): it has to match one package
MAINFILES="$NAME-common[-_][0-9] $NAME[-_][a-z]*[-_][0-9]"

export KORINFMODULE=rx

build_project /var/ftp/pvt/Etersoft/RX@Etersoft $NAME "" $@
