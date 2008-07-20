all:
	echo "Do nothing"

install: 
	mkdir -p $(bindir)/ $(sysconfdir)/eterbuild/lists
	mkdir -p $(datadir)/eterbuild/
	install -m 755 bin/build $(bindir)/korinf-build
	#install -m 644 etc/config $(sysconfdir)/eterbuild/
	#install -m 644 etc/repos $(sysconfdir)/eterbuild/
	#install -m 644 share/eterbuild/pkgrepl/pkgrepl.* $(datadir)/eterbuild/pkgrepl/
	#install -m 644 share/eterbuild/grprepl/grprepl.* $(datadir)/eterbuild/grprepl/
	#install -m 644 share/eterbuild/* $(datadir)/eterbuild/ || :
