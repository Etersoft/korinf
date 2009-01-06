pkgdatadir=$(datadir)/eterbuild

all:
	echo "Do nothing"

install: 
	mkdir -p $(bindir)/ $(sysconfdir)/eterbuild/lists
	mkdir -p $(datadir)/eterbuild/korinf $(datadir)/eterbuild/build
	install -m 755 bin/build $(bindir)/korinf
	install -m 644 etc/korinf $(sysconfdir)/eterbuild/
	cp -ap share/eterbuild/korinf/* $(pkgdatadir)/korinf/ || :
