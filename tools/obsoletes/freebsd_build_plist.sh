#!/bin/sh
public() {
rm -f pkg-plist

#get file list
rpm -ql wine libwine libwine-gl libwine-devel > plist

#remove prefix
subst 's:/usr/:/:g' plist

#replace man
subst 's:/share/man/:/man/:g' plist

#replace rc.d
subst 's:/rc.d/init.d/:/rc.d/:g' plist

#remove sysconfig and udev
grep -v "sysconfig" plist | \
grep -v "udev" | \
grep -v "var/lib/wine" | \
grep -v "share/doc/" | \
grep -v "bin/wine-kthread" | \
grep -v "bin/wine-preloader" | \
grep -v "etc/wine/config" | \
grep -v "man/man1/wineg++.1.gz" \
> plist

#remove first /
cat plist | cut -c2- | sort > pkg-plist


#add meta dirrm
cat >> pkg-plist << EOF

@dirrm share/wine/skel/windows/downloads
@dirrm share/wine/skel/windows/command
@dirrm share/wine/skel/windows
@dirrm share/wine/skel
@dirrm share/wine/ies4linux/winereg
@dirrm share/wine/ies4linux/lib
@dirrm share/wine/ies4linux/lang
@dirrm share/wine/ies4linux
@dirrm share/wine/fonts
@dirrm share/wine
@dirrm lib/wine
@dirrm include/wine/windows/ddk
@dirrm include/wine/windows
@dirrm include/wine/msvcrt/sys
@dirrm include/wine/msvcrt
@dirrm include/wine
@dirrm etc/wine

EOF

rm -f plist

}

eter() {
WINEFTP="/home/boris/ftp/pvt/Etersoft/WINE@Etersoft"
WINEVER="1.0.9"
PRODUCT=$1

rm -f pkg-plist

#get file list
rpm -qlp $WINEFTP/$WINEVER/WINE-$PRODUCT/ALTLinux/Sisyphus/wine-etersoft* > plist

#remove prefix
subst 's:/usr/:/:g' plist

#replace man
subst 's:/share/man/:/man/:g' plist

#replace rc.d
subst 's:/rc.d/init.d/:/rc.d/:g' plist

#remove first /
cat plist | cut -c2- | sort > pkg-plist-$PRODUCT

#add meta dirrm
cat >> pkg-plist-$PRODUCT << EOF

@dirrm share/wine/skel/windows/system32
@dirrm share/wine/skel/windows/command

EOF

rm -f plist

}

eter Local
eter Network
eter SQL
public
