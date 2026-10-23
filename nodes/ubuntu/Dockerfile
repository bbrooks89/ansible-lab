# Managed node: Ubuntu 24.04 booting real systemd, so services, handlers and
# `systemctl` behave the way they do on a server.
FROM ubuntu:24.04

ENV container=docker \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus \
      openssh-server sudo \
      python3 python3-apt \
      iproute2 iputils-ping ca-certificates \
 && apt-get clean
# The apt package index is kept on purpose. A real server always has one, and an
# empty index with a fresh directory timestamp fools `cache_valid_time` into
# skipping `apt update`, so package installs fail with "No package matching".

# Units that cannot work inside a container
RUN systemctl mask \
      systemd-udevd.service systemd-udevd-kernel.socket systemd-udevd-control.socket \
      systemd-modules-load.service systemd-remount-fs.service systemd-firstboot.service \
      sys-kernel-config.mount sys-kernel-debug.mount sys-kernel-tracing.mount \
      getty.target console-getty.service

# 'ansible' user: key-only login, passwordless sudo.
# Password is '*' (not '!') so sshd does not treat the account as locked.
RUN userdel -r ubuntu 2>/dev/null || true \
 && useradd -m -s /bin/bash ansible \
 && usermod -p '*' ansible \
 && echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible \
 && chmod 440 /etc/sudoers.d/ansible

COPY common/lab-firstboot         /usr/local/sbin/lab-firstboot
COPY common/lab-firstboot.service /etc/systemd/system/lab-firstboot.service
COPY common/sshd-dropin.conf      /etc/systemd/system/ssh.service.d/lab.conf
COPY common/10-lab.conf           /etc/ssh/sshd_config.d/10-lab.conf

# No baked-in host keys; run sshd as a normal service instead of socket activation
RUN chmod 755 /usr/local/sbin/lab-firstboot \
 && rm -f /etc/ssh/ssh_host_* \
 && systemctl disable ssh.socket 2>/dev/null || true \
 && systemctl enable ssh.service lab-firstboot.service

EXPOSE 22 80
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
