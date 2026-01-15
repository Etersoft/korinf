FROM ubuntu:23.10

# TODO: install epm
# enable i386
RUN DEBIAN_FRONTEND=noninteractive dpkg --add-architecture i386
RUN apt-get update

# rpm-build
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libtool automake autoconf gzip bzip2 pkg-config cpio patch gcc coreutils grep make rpm gawk
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libc6-dev:i386
# Debian specific
RUN  DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential alien fakeroot debhelper

RUN  DEBIAN_FRONTEND=noninteractive apt-get install -y curl iproute2 mc

RUN useradd -m korinfer

ENTRYPOINT ["sleep"]
CMD ["6000"]
