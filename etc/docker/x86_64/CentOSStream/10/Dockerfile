FROM quay.io/centos/centos:stream10

# Required by the initial eepm RPM before a dependency solver is bootstrapped.
RUN dnf install -y rpm-build make coreutils-common

RUN useradd -m korinfer

ENTRYPOINT ["sleep"]
CMD ["6000"]
