FROM fedora:35

# TODO: install epm
# RPM specific
# rpm-build
#RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libtool automake autoconf gzip bzip2 pkg-config cpio patch gcc coreutils grep make rpm gawk
#RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libc6-dev
# Debian specific
#RUN  DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential alien fakeroot debhelper

RUN useradd -m korinfer

ENTRYPOINT ["sleep"]
CMD ["6000"]
