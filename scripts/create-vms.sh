#!/usr/bin/env bash

set -euo pipefail

SSH_KEY="${1:?Usage: $0 <ssh-public-key> [instances_file]}"
INSTANCES_FILE="${2:-instances}"

if [[ ! -f "$INSTANCES_FILE" ]]; then
    echo "Instances file not found: $INSTANCES_FILE" >&2
    exit 1
fi


BASE_IMAGE="/var/lib/libvirt/images/jammy-server-cloudimg-amd64.img"

if [[ ! -f "$BASE_IMAGE" ]]; then
  echo "Base image not found: $BASE_IMAGE" >&2
  exit 1
fi
qemu-img info "$BASE_IMAGE"

while IFS=":" read -r host role mem cpu ip || [[ -n "$host" ]]; do
    [[ -z "$host" || "$host" =~ ^[[:space:]]*# ]] && continue


    VM_DISK="/var/lib/libvirt/images/${host}.qcow2"
    USER_DATA="/tmp/${host}-user-data.yaml"
    NETWORK_CONFIG="/tmp/${host}-network-config.yaml"

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

cat > "$NETWORK_CONFIG" <<EOF
#network-config
version: 2
ethernets:
  enp1s0:
    addresses:
      - ${ip}/24
    routes:
      - to: default
        via: 10.240.0.1
    nameservers:
      addresses:
        - 10.240.0.1
EOF

    echo "Creating $host (role $role, mem $mem Mi, cpu: $cpu)..."

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
       --cloud-init user-data="${USER_DATA}",network-config="${NETWORK_CONFIG}" 
done < "$INSTANCES_FILE"
