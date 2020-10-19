FROM ubuntu:focal

# TODO: install epm
# RPM specific
RUN apt-get install libtool automake autoconf rpm-build glibc-devel gzip bzip2 pkg-config cpio patch gcc coreutils grep make rpm gawk
# Debian specific
RUN apt-get install build-essential alien fakeroot debhelper

RUN useradd korinfer
