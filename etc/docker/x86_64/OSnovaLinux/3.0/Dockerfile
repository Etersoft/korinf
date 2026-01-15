FROM x86-64-osnova-3.0-base

# TODO: install epm
# RPM specific
RUN apt-get update
# rpm-build
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libtool automake autoconf gzip bzip2 pkg-config cpio patch gcc coreutils grep make rpm gawk
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libc6-dev
# Debian specific
RUN  DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential fakeroot debhelper
RUN  DEBIAN_FRONTEND=noninteractive apt-get install -y curl bash
RUN curl -sL https://eepm.ru/epm.sh | bash /dev/stdin ei
# alien missed
#RUN  DEBIAN_FRONTEND=noninteractive apt-get install -y http://mirror.yandex.ru/debian/pool/main/a/alien/alien_8.95.8_all.deb
RUN  epmi --auto http://mirror.yandex.ru/debian/pool/main/a/alien/alien_8.95.8_all.deb

RUN useradd -m korinfer

ENTRYPOINT ["sleep"]
CMD ["6000"]
