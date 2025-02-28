instance-id: ${hostname}
local-hostname: ${hostname}
network:
  version: 2
  ethernets:
    ens192:
      addresses:
        - ${ip_address}
      routes:
      - to: default
        via: ${gateway}
      nameservers:
        addresses:
          - ${nameserver}