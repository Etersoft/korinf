FROM x86-64-alteros:9.5

# TODO: install epm
# RPM specific
RUN rpm -e etckeeper etckeeper-dnf
RUN dnf install -y rpm-build

RUN useradd -m korinfer

ENTRYPOINT ["sleep"]
CMD ["6000"]
