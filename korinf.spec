Name: korinf
Version: 0.9
Release: alt1

Summary: Korinf build system

License: Public domain
Group: Development/Other
#Url: http://www.freesource.info/wiki/AltLinux/Razrabotchiku/SborkaPaketov

Packager: Vitaly Lipatov <lav@altlinux.ru>

# git-clone http://git.altlinux.org/people/lav/packages/korinf.git
Source: %name-%version.tar

BuildArchitectures: noarch

%description
This package contains Korinf build system.

%prep
%setup -q

%build
%make

%install
%makeinstall

%files
%doc README TODO NEWS
%_bindir/korinf-build

%changelog
* Sun Jul 20 2008 Vitaly Lipatov <lav@altlinux.ru> 0.9-alt1
- initial build for ALT Linux Sisyphus

