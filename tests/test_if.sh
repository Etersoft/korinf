instr_test()
{
       echo "$1" | grep -q "$2"
       return  $?
}


func()
{
instr_test "$DIST" "ArchLinux"
DD=`instr_test "$DIST" "ArchLinux"`
return
if [ ! $( instr_test "$DIST" "ArchLinux" ) -a ! $( instr_test "$DIST" "Gentoo" ) ] ; then
       echo "$1: Hello"
else
       echo "$1: False"
fi
}

DIST="" func Empty
DIST="ArchLinux/2010" func ArchLinux
DIST="Gentoo/2000" func Gentoo
