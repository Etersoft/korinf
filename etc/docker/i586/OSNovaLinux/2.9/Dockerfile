FROM osnovalinux-2.9:latest

# TODO: install epm
# RPM specific
RUN apt-get update

# missed:
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y /alien_8.95_all.deb

# rpm-build
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libtool automake autoconf gzip bzip2 pkg-config cpio patch gcc coreutils grep make rpm gawk
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libc6-dev
# Debian specific
RUN  DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential alien fakeroot debhelper

RUN  DEBIAN_FRONTEND=noninteractive apt-get install -y curl iproute2
# missed: mc

RUN useradd -m korinfer

ENTRYPOINT ["sleep"]
CMD ["6000"]
