#!/usr/bin/env bash
# Generates the lab keypair on first start (or after `./lab reset` wipes the volumes)
# and hands the private key to the 'ansible' user. Managed nodes only ever see the
# public key, via the read-only lab-pubkey volume.
set -euo pipefail

SECRET=/lab-secret/id_ed25519
PUB=/lab-pubkey/id_ed25519.pub

if [[ ! -s "$SECRET" ]]; then
  echo "[control] generating new lab keypair"
  rm -f "$SECRET" "$SECRET.pub"
  ssh-keygen -q -t ed25519 -N '' -C "ansible-lab" -f "$SECRET"
fi
chmod 600 "$SECRET"

# Publish the public key last: the compose healthcheck waits for this file,
# so the managed nodes never start before a complete keypair exists.
cp "$SECRET.pub" "$PUB.tmp" && chmod 644 "$PUB.tmp" && mv "$PUB.tmp" "$PUB"

install -d -m 700 -o ansible -g ansible /home/ansible/.ssh
install -m 600 -o ansible -g ansible "$SECRET" /home/ansible/.ssh/id_ed25519
install -m 644 -o ansible -g ansible "$PUB" /home/ansible/.ssh/id_ed25519.pub

exec "$@"
