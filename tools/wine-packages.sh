#!/bin/bash
# Show table of WINE@Etersoft packages with build dates
# (c) 2026 Etersoft
# Authors: Vitaly Lipatov <lav@etersoft.ru>
#          Claude Opus 4.6 <noreply@anthropic.com>

PUBDIR="/var/ftp/pub/Etersoft/WINE@Etersoft"

# Colors
setup_colors() {
    if [ "$FORCE_COLOR" = 1 ] || [ -t 1 ]; then
        C_GREEN=$'\e[0;32m'
        C_RED=$'\e[0;31m'
        C_YELLOW=$'\e[0;33m'
        C_GRAY=$'\e[0;90m'
        C_BOLD=$'\e[1m'
        C_RESET=$'\e[0m'
    else
        C_GREEN='' C_RED='' C_YELLOW='' C_GRAY='' C_BOLD='' C_RESET=''
    fi
}

print_help() {
    cat <<EOF
Usage: wine-packages.sh [options] [VERSION]

Show table of WINE@Etersoft packages for all distributions.
Uses distro.list from wine-etersoft.sh as the source of systems.

Options:
  -h, --help        Show this help
  -v, --versions    List available versions
  -s, --short       Short output (package version only, no full filename)
  --color           Force color output

Arguments:
  VERSION           WINE@Etersoft version (default: 10)

Examples:
  wine-packages.sh                  # Show packages for version 10
  wine-packages.sh 10-testing       # Show packages for 10-testing
  wine-packages.sh -s 9.0           # Short format for version 9.0
  wine-packages.sh --versions       # List all available versions
EOF
}

list_versions() {
    echo "Available WINE@Etersoft versions:"
    for d in "$PUBDIR"/*/WINE; do
        basename "$(dirname "$d")"
    done | sort -V
}

# Parse distro.list the same way korinf does
parse_distro_list() {
    local list="$1"
    awk -F'\t' '/^[^#.]/ && $1 != "" {print $1}' "$list" | sort -u -t/ -k1,1 -k2,2 -k3,3V
}

# Find main wine-etersoft package
find_wine_pkg() {
    local dir="$1"
    local arch="$2" # x86_64 or i586
    local pkg

    [ -d "$dir" ] || return

    if [ "$arch" = "x86_64" ]; then
        pkg=$(ls "$dir"/wine-etersoft-[0-9]*.x86_64.rpm 2>/dev/null | head -1)
        [ -z "$pkg" ] && pkg=$(ls "$dir"/wine-etersoft_[0-9]*_amd64.deb 2>/dev/null | head -1)
    else
        pkg=$(ls "$dir"/wine32-etersoft-[0-9]*.i586.rpm 2>/dev/null | head -1)
        [ -z "$pkg" ] && pkg=$(ls "$dir"/wine-etersoft-[0-9]*.i586.rpm 2>/dev/null | head -1)
        [ -z "$pkg" ] && pkg=$(ls "$dir"/wine32-etersoft_[0-9]*_i386.deb 2>/dev/null | head -1)
        [ -z "$pkg" ] && pkg=$(ls "$dir"/wine-etersoft_[0-9]*_i386.deb 2>/dev/null | head -1)
    fi

    [ -n "$pkg" ] && echo "$pkg"
}

pkg_version() {
    local name
    name=$(basename "$1")
    if [[ "$name" == *.rpm ]]; then
        echo "$name" | sed 's/^wine32-etersoft-//;s/^wine-etersoft-//;s/-.*//'
    elif [[ "$name" == *.deb ]]; then
        echo "$name" | sed 's/^wine32-etersoft_//;s/^wine-etersoft_//;s/-.*//'
    fi
}

format_date() {
    [ -z "$1" ] || [ ! -f "$1" ] && return
    stat -c '%Y' "$1" | xargs -I{} date -d @{} '+%Y-%m-%d'
}

# Main
SHORT=0
FORCE_COLOR=0
VERSION="10"

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) print_help; exit 0 ;;
        -v|--versions) list_versions; exit 0 ;;
        -s|--short) SHORT=1 ;;
        --color) FORCE_COLOR=1 ;;
        -*) echo "Unknown option: $1" >&2; exit 1 ;;
        *) VERSION="$1" ;;
    esac
    shift
done

setup_colors

BASEDIR="$PUBDIR/$VERSION"
WINEDIR="$BASEDIR/WINE"
DISTROLIST="$BASEDIR/distro.list"

if [ ! -f "$DISTROLIST" ]; then
    echo "Error: $DISTROLIST not found" >&2
    echo "Use --versions to list available versions" >&2
    exit 1
fi

# Get unique distro entries from distro.list
# Entries are like: x86_64/ALTLinux/p11 or ALTLinux/p11
mapfile -t DISTROS < <(parse_distro_list "$DISTROLIST")

# Counters
total=0 cnt_ok=0 cnt_mismatch=0 cnt_only64=0 cnt_only32=0 cnt_empty=0

# Print header
echo ""
echo "${C_BOLD}WINE@Etersoft $VERSION${C_RESET}  (from $DISTROLIST)"
echo ""

if [ "$SHORT" -eq 1 ]; then
    printf "${C_BOLD}%-4s %-28s  %-12s %-12s  %-12s %-12s${C_RESET}\n" "" "Distro/Version" "64-bit" "Date" "32-bit" "Date"
    printf "%-4s %-28s  %-12s %-12s  %-12s %-12s\n" "----" "----------------------------" "------------" "----------" "------------" "----------"
else
    printf "${C_BOLD}%-4s %-28s  %-50s %-12s  %-50s %-12s${C_RESET}\n" "" "Distro/Version" "64-bit package" "Date" "32-bit package" "Date"
    printf "%-4s %-28s  %-50s %-12s  %-50s %-12s\n" "----" "----------------------------" "--------------------------------------------------" "----------" "--------------------------------------------------" "----------"
fi

for entry in "${DISTROS[@]}"; do
    # entry is like x86_64/ALTLinux/p11 or ALTLinux/p11
    # Normalize: extract distro/version without arch prefix
    if [[ "$entry" == x86_64/* ]]; then
        distro_ver="${entry#x86_64/}"
    else
        distro_ver="$entry"
    fi

    # 64-bit path: WINE/x86_64/Distro/Version
    dir64="$WINEDIR/x86_64/$distro_ver"
    pkg64=$(find_wine_pkg "$dir64" "x86_64")

    # 32-bit path: WINE/Distro/Version (without x86_64)
    dir32="$WINEDIR/$distro_ver"
    pkg32=$(find_wine_pkg "$dir32" "i586")

    ver64="" ver32="" date64="" date32=""
    [ -n "$pkg64" ] && ver64=$(pkg_version "$pkg64") && date64=$(format_date "$pkg64")
    [ -n "$pkg32" ] && ver32=$(pkg_version "$pkg32") && date32=$(format_date "$pkg32")

    # Status
    total=$((total + 1))
    if [ -n "$ver64" ] && [ -n "$ver32" ]; then
        if [ "$ver64" = "$ver32" ]; then
            status="ok"; cnt_ok=$((cnt_ok + 1))
        else
            status="mismatch"; cnt_mismatch=$((cnt_mismatch + 1))
        fi
    elif [ -n "$ver64" ]; then
        status="only64"; cnt_only64=$((cnt_only64 + 1))
    elif [ -n "$ver32" ]; then
        status="only32"; cnt_only32=$((cnt_only32 + 1))
    else
        status="empty"; cnt_empty=$((cnt_empty + 1))
    fi

    # Color and icon
    case "$status" in
        ok)       color="$C_GREEN";  icon="OK" ;;
        mismatch) color="$C_RED";    icon="!!" ;;
        only64)   color="$C_YELLOW"; icon="64" ;;
        only32)   color="$C_YELLOW"; icon="32" ;;
        empty)    color="$C_GRAY";   icon="--" ;;
    esac

    # Format names
    if [ "$SHORT" -eq 1 ]; then
        name64="${ver64:--}"
        name32="${ver32:--}"
    else
        [ -n "$pkg64" ] && name64=$(basename "$pkg64") || name64="-"
        [ -n "$pkg32" ] && name32=$(basename "$pkg32") || name32="-"
    fi

    if [ "$SHORT" -eq 1 ]; then
        printf "%s%-4s%s %-28s  %-12s %-12s  %-12s %-12s\n" \
            "$color" "$icon" "$C_RESET" "$distro_ver" "$name64" "${date64:--}" "$name32" "${date32:--}"
    else
        printf "%s%-4s%s %-28s  %-50s %-12s  %-50s %-12s\n" \
            "$color" "$icon" "$C_RESET" "$distro_ver" "$name64" "${date64:--}" "$name32" "${date32:--}"
    fi
done

# Summary
echo ""
printf "${C_BOLD}Total: %d${C_RESET}  " "$total"
[ "$cnt_ok" -gt 0 ]       && printf "${C_GREEN}OK: %d${C_RESET}  " "$cnt_ok"
[ "$cnt_mismatch" -gt 0 ] && printf "${C_RED}Mismatch: %d${C_RESET}  " "$cnt_mismatch"
[ "$cnt_only64" -gt 0 ]   && printf "${C_YELLOW}64-bit only: %d${C_RESET}  " "$cnt_only64"
[ "$cnt_only32" -gt 0 ]   && printf "${C_YELLOW}32-bit only: %d${C_RESET}  " "$cnt_only32"
[ "$cnt_empty" -gt 0 ]    && printf "${C_GRAY}Empty: %d${C_RESET}  " "$cnt_empty"
echo ""
echo ""
echo "Legend: ${C_GREEN}OK${C_RESET}=match  ${C_RED}!!${C_RESET}=mismatch  ${C_YELLOW}64${C_RESET}=64-only  ${C_YELLOW}32${C_RESET}=32-only  ${C_GRAY}--${C_RESET}=empty"
