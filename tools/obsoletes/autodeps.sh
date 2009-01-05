#!/bin/sh

#QUERY_FILE_CMD="rpm -qf"
QUERY_FILE_CMD="dpkg -S"
#QUERY_PKG_CMD="rpm -q"
QUERY_PKG_CMD="dpkg -l"

HELPER_FUNCTIONS='
function query_version(name,    cmd, str, pkg) {
    cmd = "dpkg -l " name " 2>/dev/null";
    while ((cmd | getline str) > 0) {
        if(match(str, /^ii[[:blank:]]+[^[:blank:]]+[[:blank:]]+([^[:blank:]]+)/, pkg) > 0) break;
    }
    close(cmd);
    return pkg[1];
}

function query_file(name,    cmd, str, s, pkg) {
    # obtain the last line of dpkg output
    cmd = "dpkg -S " name " 2>/dev/null";
    while ((cmd | getline s) > 0) str = s;
    close(cmd);
    if(match(str, /^([^[:blank:]]+):/, pkg) > 0) return pkg[1];
}
'

while getopts ":c:" opt; do
    case $opt in
        c ) COND="$OPTARG"
    esac
done
shift $(($OPTIND - 1))


rpm -qRp "$1" | awk -v "cond=${COND}" --source "${HELPER_FUNCTIONS}" --source \
		    '/\.so(\.[[:digit:]]+)*(\(.*\))?[[:blank:]]*$/ {
                         lib = $0;
                         gsub(/\(.*\)/, "", lib);
			 if (system("test -f /lib/" lib) == 0) {
			     pkg=query_file("/lib/" lib);
			     print (cond != "" ? pkg " (" cond " " query_version(pkg) ")" : pkg);
			 } else if (system("test -f /usr/lib/" lib) == 0) {
			     pkg=query_file("/usr/lib/" lib);
			     print (cond != "" ? pkg " (" cond " " query_version(pkg) ")" : pkg);
			 }

			 next;
		     }

                     /^\// && !/\(.*\)/ {
			 if (system("test -f " $0) == 0) {
			         pkg=query_file($0);
			         print (cond != "" ? pkg " (" cond " " query_version(pkg) ")" : pkg);
			 }

			 next;
		     }

		     !/^\// && !/\(.*\)/ {
		         if(NF == 3)
			     print tolower($1) " (" $2 " " $3 ")";
			 else if(NF == 1)
                             print tolower($0);
		     }' | sort | uniq | awk 'BEGIN {first=0;} {if(first==0) {deps=$0; first=1;} else deps=deps ", " $0;} END {print deps;}'
