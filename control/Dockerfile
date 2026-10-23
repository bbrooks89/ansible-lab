FROM ubuntu:24.04

# Match the host user's UID/GID so files created in ./workspace stay yours.
# ./lab passes these automatically.
ARG LAB_UID=1000
ARG LAB_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3 python3-venv \
      openssh-client sshpass \
      git vim-tiny less tree jq \
      iputils-ping dnsutils curl ca-certificates \
      tini \
 && rm -rf /var/lib/apt/lists/*

# The base image ships a 'ubuntu' user at UID 1000; remove it so 'ansible' can take that UID.
RUN userdel -r ubuntu 2>/dev/null || true \
 && (getent group "${LAB_GID}" >/dev/null || groupadd -g "${LAB_GID}" ansible) \
 && useradd -m -u "${LAB_UID}" -g "${LAB_GID}" -s /bin/bash ansible

# Ansible in its own venv, version pinned in requirements.txt
COPY requirements.txt requirements.yml /opt/lab/
RUN python3 -m venv /opt/ansible \
 && /opt/ansible/bin/pip install --no-cache-dir -r /opt/lab/requirements.txt

ENV PATH=/opt/ansible/bin:$PATH \
    ANSIBLE_CONFIG=/home/ansible/lab/ansible.cfg

RUN ansible-galaxy collection install -r /opt/lab/requirements.yml \
      -p /usr/share/ansible/collections \
 && printf 'export PATH=/opt/ansible/bin:$PATH\nexport ANSIBLE_CONFIG=/home/ansible/lab/ansible.cfg\n' \
      > /etc/profile.d/ansible.sh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
