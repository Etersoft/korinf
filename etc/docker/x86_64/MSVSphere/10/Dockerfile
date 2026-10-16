FROM inferit/msvsphere:10

# TODO: install epm
# RPM specific
# Keep RPM and OpenSSL in sync before installing build tools.
RUN dnf upgrade -y && dnf install -y rpm-build && rpm -q rpm-build

RUN useradd -m korinfer

ENTRYPOINT ["sleep"]
CMD ["6000"]
