FROM archlinux:base-devel

# TODO: install epm
RUN pacman --noconfirm -Syu
RUN pacman --noconfirm -S curl
RUN curl https://raw.githubusercontent.com/Etersoft/eepm/master/packed/epm.sh >/usr/bin/epm && chmod 755 /usr/bin/epm
# rpm-build
RUN epm install --auto libtool automake autoconf gzip bzip2 pkg-config cpio patch gcc coreutils grep make rpm gawk
#RUN epm --auto libc6-dev
# Debian specific
#RUN  DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential alien fakeroot debhelper
RUN epm install --auto curl iproute2 mc

RUN useradd -m korinfer

ENTRYPOINT ["sleep"]
CMD ["6000"]
