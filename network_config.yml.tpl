instance-id: ${hostname}
local-hostname: ${hostname}
network:
  version: 2
  ethernets:
    ${network_interface}:
      dhcp4: false
      dhcp6: false
      addresses:
        - ${ip_address}
      routes:
      - to: default
        via: ${gateway}
      nameservers:
        addresses:
          - ${nameserver}