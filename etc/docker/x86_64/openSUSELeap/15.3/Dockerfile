FROM opensuse/leap:15.3

# TODO: install epm

RUN yes | zypper --non-interactive install rpmbuild

RUN useradd -m korinfer

ENTRYPOINT ["sleep"]
CMD ["6000"]
