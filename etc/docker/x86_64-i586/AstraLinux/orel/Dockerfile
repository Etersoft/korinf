FROM x86-64-astralinux-orel:2.12

# TODO: install epm
# RPM specific
RUN apt-get update
# enable i386
RUN DEBIAN_FRONTEND=noninteractive dpkg --add-architecture i386
# rpm-build
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libtool automake autoconf gzip bzip2 pkg-config cpio patch gcc coreutils grep make rpm gawk
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libc6-dev
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libusb-1.0-dev
# Debian specific
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential alien fakeroot debhelper

RUN DEBIAN_FRONTEND=noninteractive apt-get remove -y libgl-dev
# hack to install ia32-libs and libgl-dev together
RUN mkdir /tmp && chmod 1777 /tmp && cd /tmp && apt-get download libgl-dev && ar -x libgl-dev* && tar xf "data.tar.xz" && rm -v data.tar.xz && rm -v libgl-dev* && cp -av usr / && rm -rf usr/

RUN ln -s /usr/lib32/i386-linux-gnu /usr/lib

# install missed libvulkan1 i386
#RUN cd /tmp && wget https://mirror.yandex.ru/debian/pool/main/v/vulkan/libvulkan1_1.0.39.0%2Bdfsg1-1_i386.deb && wget https://mirror.yandex.ru/debian/pool/main/v/vulkan/libvulkan-dev_1.0.39.0%2Bdfsg1-1_i386.deb && DEBIAN_FRONTEND=noninteractive dpkg -i libvulkan1*i386.deb
RUN cd /tmp && wget https://mirror.yandex.ru/debian/pool/main/v/vulkan/libvulkan1_1.0.39.0%2Bdfsg1-1_i386.deb && DEBIAN_FRONTEND=noninteractive dpkg -i libvulkan1*i386.deb

RUN ln -s libvulkan.so.1 /usr/lib/i386-linux-gnu/libvulkan.so ; ln -s libXpm.so.4 /usr/lib32/i386-linux-gnu/libXpm.so

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y ia32-libs-dev
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libssl-dev && ln -s /usr/include/x86_64-linux-gnu/openssl/opensslconf.h /usr/include/openssl/opensslconf.h

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libusb-1.0-0-dev
RUN cp -a /usr/lib/x86_64-linux-gnu/pkgconfig/libusb-1.0.pc /usr/lib32/i386-linux-gnu/pkgconfig/
sed -i -e "s|x86_64-linux-gnu|i386-linux-gnu|g" /usr/lib32/i386-linux-gnu/pkgconfig/libusb-1.0.pc

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libkrb5-dev krb5-multidev
RUN cp -a /usr/lib/x86_64-linux-gnu/mit-krb5 /usr/lib32/i386-linux-gnu
RUN cp -a /usr/lib/x86_64-linux-gnu/pkgconfig/mit-krb5 /usr/lib32/i386-linux-gnu/pkgconfig ; sed -i -e "s|x86_64-linux-gnu|i386-linux-gnu|g" /usr/lib32/i386-linux-gnu/pkgconfig/mit-krb5/*.pc
# really still used pkgconfig from x86_64
RUN sed -i -e "s|x86_64-linux-gnu|i386-linux-gnu|g" -e "s|-lcom_err||" /usr/lib/x86_64-linux-gnu/pkgconfig/mit-krb5/*.pc /usr/lib/x86_64-linux-gnu/pkgconfig/mit-k*.pc

RUN useradd -m korinfer

ENTRYPOINT ["sleep"]
CMD ["6000"]
