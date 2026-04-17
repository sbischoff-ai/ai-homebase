#cloud-config
hostname: __VM_NAME__
package_update: true
package_upgrade: false
packages:
  - docker.io
  - openssh-server
  - ca-certificates
  - dnsmasq

users:
  - default
  - name: __REMOTE_USER__
    gecos: __REMOTE_USER_GECOS__
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - __SSH_PUBLIC_KEY__

write_files:
  - path: /etc/docker/daemon.json
    permissions: '0644'
    content: |
__DOCKER_DAEMON_JSON__

runcmd:
  - systemctl enable --now ssh
  - systemctl enable --now docker.service
  - usermod -aG docker __REMOTE_USER__
  - loginctl enable-linger __REMOTE_USER__
