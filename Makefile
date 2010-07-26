pkgdatadir=$(datadir)/eterbuild

all:
	echo "Do nothing"

install: 
	mkdir -p $(bindir)/ $(sysconfdir)/eterbuild/lists
	mkdir $(sysconfdir)/eterbuild/rpmopt
	mkdir -p $(datadir)/eterbuild/korinf $(datadir)/eterbuild/build
	install -m 755 bin/korinf $(bindir)/korinf
	install -m 755 tools/login.sh $(bindir)/korlogin
	install -m 644 etc/korinf $(sysconfdir)/eterbuild/
	install -m 644 etc/linked $(sysconfdir)/eterbuild/
	install -m 644 etc/lists/* $(sysconfdir)/eterbuild/lists/
	install -m 644 etc/rpmopt/* $(sysconfdir)/eterbuild/rpmopt/
	cp -ap share/eterbuild/korinf/* $(pkgdatadir)/korinf/ || :
