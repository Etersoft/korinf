Name: korinf
Version: 1.7
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

Requires: etersoft-build-utils >= 1.5.6

%description
This package contains Korinf build system.

%prep
%setup -q

%build
%make

%install
%makeinstall

%files
%doc README TODO NEWS AUTHORS COPYING
%_bindir/korinf
%dir %_sysconfdir/eterbuild/lists/
%config(noreplace) %_sysconfdir/eterbuild/lists/*
%config(noreplace) %_sysconfdir/eterbuild/korinf
%_datadir/eterbuild/korinf/

%changelog
* Sat Mar 07 2009 Vitaly Lipatov <lav@altlinux.ru> 1.7-alt1
- improve code, fix to user etersoft-build-utils 1.5.6

* Wed Jan 14 2009 Vitaly Lipatov <lav@altlinux.ru> 1.6-alt1
- update version

* Tue Jan 06 2009 Vitaly Lipatov <lav@altlinux.ru> 1.5-alt1
- update to lastest source, big restructure
- change License to GPLv3

* Sun Jul 20 2008 Vitaly Lipatov <lav@altlinux.ru> 0.9-alt1
- initial build for ALT Linux Sisyphus

