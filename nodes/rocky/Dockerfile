# Managed node: Rocky Linux 9 (RHEL family) booting real systemd.
FROM rockylinux/rockylinux:9

ENV container=docker

RUN dnf -y install \
      systemd openssh-server openssh-clients sudo \
      python3 iproute procps-ng hostname \
 && dnf clean all

# Units that cannot work inside a container
RUN systemctl mask \
      systemd-udevd.service systemd-udevd-kernel.socket systemd-udevd-control.socket \
      systemd-modules-load.service systemd-remount-fs.service systemd-firstboot.service \
      sys-kernel-config.mount sys-kernel-debug.mount sys-kernel-tracing.mount \
      getty.target console-getty.service

# 'ansible' user: key-only login, passwordless sudo
RUN useradd -m -s /bin/bash ansible \
 && usermod -p '*' ansible \
 && echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible \
 && chmod 440 /etc/sudoers.d/ansible

COPY common/lab-firstboot         /usr/local/sbin/lab-firstboot
COPY common/lab-firstboot.service /etc/systemd/system/lab-firstboot.service
COPY common/sshd-dropin.conf      /etc/systemd/system/sshd.service.d/lab.conf
COPY common/10-lab.conf           /etc/ssh/sshd_config.d/10-lab.conf

RUN chmod 755 /usr/local/sbin/lab-firstboot \
 && rm -f /etc/ssh/ssh_host_* \
 && systemctl enable sshd.service lab-firstboot.service

EXPOSE 22 80
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
