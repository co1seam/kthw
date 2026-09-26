#!/usr/bin/env bash

set -euo pipefail

SSH_KEY="${1:?Usage: $0 <ssh-public-key>}"

BASE_IMAGE="/var/lib/libvirt/images/jammy-server-cloudimg-amd64.img"

if [[ ! -f "$BASE_IMAGE" ]]; then
  echo "Base image not found: $BASE_IMAGE" >&2
  exit 1
fi
qemu-img info "$BASE_IMAGE"

machines=(
  "bastion-host:2048:1"
  "server:2048:1"
  "node-0:2048:1"
  "node-1:2048:1"
)

for i in "${machines[@]}"; do
    IFS=":" read -r host mem cpu <<< "$i"

    VM_DISK="/var/lib/libvirt/images/${host}.qcow2"
    USER_DATA="/tmp/${host}-user-data.yaml"

    if [[ ! -f "$VM_DISK" ]]; then
      qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMAGE" "$VM_DISK" 20G
    fi

cat > "$USER_DATA" <<EOF
#cloud-config
hostname: "${host}"
users:
  - name: k8s
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
        - ${SSH_KEY}
package_update: true
packages:
  - qemu-guest-agent
  - curl
  - wget
  - vim
runcmd:
  - systemctl enable --now qemu-guest-agent
EOF

    virt-install \
       --name "${host}" \
       --memory "${mem}" \
       --vcpus "${cpu}" \
       --disk path="${VM_DISK}",bus=virtio \
       --import \
       --os-variant ubuntu22.04 \
       --network network=kthw,model=virtio \
       --graphics none \
       --console pty,target_type=serial \
       --noautoconsole \
       --cloud-init user-data="${USER_DATA}" 
done
