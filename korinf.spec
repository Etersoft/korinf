Name: korinf
Version: 1.8.6
Release: alt1

Summary: Korinf build system

License: AGPLv3
Group: Development/Other
Url: http://freesource.info/wiki/korinf

Packager: Vitaly Lipatov <lav@altlinux.ru>

# git-clone http://git.altlinux.org/people/lav/packages/korinf.git
# git-clone http://git.etersoft.ru/people/lav/packages/korinf.git
Source: %name-%version.tar

BuildArchitectures: noarch

Requires: etersoft-build-utils >= 1.7.9
Requires: alien

%description
This package contains Korinf build system.

%prep
%setup

%build
%make

%install
%makeinstall

%files
%doc README TODO NEWS AUTHORS COPYING
%_bindir/korinf
%_bindir/korlogin
%dir %_sysconfdir/eterbuild/lists/
%config(noreplace) %_sysconfdir/eterbuild/lists/*
%config(noreplace) %_sysconfdir/eterbuild/rpmopt/*
%config(noreplace) %_sysconfdir/eterbuild/korinf
%_datadir/eterbuild/korinf/

%changelog
* Tue Mar 09 2010 Vitaly Lipatov <lav@altlinux.ru> 1.8.6-alt1
- many fixes and rewrites with many improvements
- korinf: rewrite script, fix args handling and build list
- initial support for Linked system, autocreate links
- add initial rpmopt support (options for rpm build in etc/rpmopt/system file
- do not build repo index due rpm-dir using instead
- check_products: add -b key support (for build)

* Sat Nov 21 2009 Vitaly Lipatov <lav@altlinux.ru> 1.8.5-alt1
- common: incorporate in get_distr_list filter_distr_list for support SKIPBUILDLIST
- now 'all' builds only for target distro. For build for all distros, use ALL keyword.
- check_built: set MIS in the status column
- queuewatcher: add flag to run now
- fixes for ebuilds
- replace Gentoo hack with more clean one
- install_wine: add initial install support
- config: export global variable, always include system wide config from /etc/eterbuild/korinf
- introduce PUBLICURL and FTPDIR and use it for DESTURL
- rpm: fix alien using in 32-bit environment for 64-bit target
- add wrapper used in dpkg-architecture
- korlogin: use system name instead chroot
- korinf: fix target dir detecting from spec
- robot build: get project version from SOURCEPATH
- distro: additional TARGET check

* Wed Aug 05 2009 Vitaly Lipatov <lav@altlinux.ru> 1.8.4-alt1
- build Gentoo and ArchLinux in generic way, fix TARGET vars setting
- add new scripts for run task in all OSes
- rewrite build freebsd scripts
- korinf: add -b param (buildstrap build enable)
- add korlogin script to log in the chroot system
- small improvements

* Fri Jul 24 2009 Vitaly Lipatov <lav@altlinux.ru> 1.8.3-alt1
- korinf: do not use subdir by default
- skip Windows build
- copying: add apt repo generating after build
- Author: Vitaly Lipatov <lav@etersoft.ru>

* Mon Jul 20 2009 Vitaly Lipatov <lav@altlinux.ru> 1.8.2-alt1
- bin/korinf: add support for build from spec (use rpmpub), add optional target support
- common: add support for installed korinf and installed etersoft-build-utils
- fix FreeBSD build
- small improvements

* Tue Jul 14 2009 Vitaly Lipatov <lav@altlinux.ru> 1.8.1-alt1
- add need for versioned etersoft-build-utils
- rewrite freebsd build related scripts
- get_rpm_sources: add TARGET/Windows support
- rpm: write config log separately
- correct set BUILDARCH (parse dist)
- use bin/korinf with standart build_package function
- do not need etersoft-build-utils anymore in target system

* Fri Jun 12 2009 Vitaly Lipatov <lav@altlinux.ru> 1.8-alt1
- improve and cleanup code, use etersoft-build-utils >= 1.6.0
- convert src.rpm in host system now

* Sat Mar 07 2009 Vitaly Lipatov <lav@altlinux.ru> 1.7-alt1
- improve code, fix to use etersoft-build-utils 1.5.6

* Wed Jan 14 2009 Vitaly Lipatov <lav@altlinux.ru> 1.6-alt1
- update version

* Tue Jan 06 2009 Vitaly Lipatov <lav@altlinux.ru> 1.5-alt1
- update to lastest source, big restructure
- change License to GPLv3

* Sun Jul 20 2008 Vitaly Lipatov <lav@altlinux.ru> 0.9-alt1
- initial build for ALT Linux Sisyphus

