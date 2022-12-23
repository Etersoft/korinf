FROM x86-64-astralinux:1.7

# TODO: install epm
# add extended repo for ia32-libs
#RUN echo "deb https://dl.astralinux.ru/astra/stable/1.7_x86-64/repository-extended/ 1.7_x86-64 main contrib non-free" >> /etc/apt/sources.list
RUN apt-get update
# rpm-build
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libtool automake autoconf gzip bzip2 pkg-config cpio patch gcc coreutils grep make rpm gawk
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libc6-dev
# Debian specific
RUN  DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential alien fakeroot debhelper

RUN useradd -m korinfer

ENTRYPOINT ["sleep"]
CMD ["6000"]
