# Host-Only Network Specification

## Purpose

Define the isolated libvirt network that backs the guest: a host-only bridge with no NAT or route to the LAN, reachable exclusively from the host.

## Requirements

### Requirement: No forwarding

The network SHALL be defined without a `forward` block. The absence of forwarding is what keeps the VM off the LAN; there SHALL be no NAT and no routing to external networks.

#### Scenario: Apply the network

- **WHEN** the network is created
- **THEN** the resulting libvirt network has no `<forward>` element and the guest has no path to the LAN or internet

#### Scenario: Guest-to-guest traffic

- **WHEN** two guests attach to the same network
- **THEN** they can reach each other directly over the bridge

### Requirement: Bridge device

The network SHALL create a Linux bridge named `virbr-tofu` with STP enabled.

#### Scenario: Host bridge creation

- **WHEN** the network is started
- **THEN** the bridge `virbr-tofu` exists on the host with STP on

### Requirement: Local-only DNS domain

The network SHALL declare the DNS domain `tofu-localhost` marked local-only, so dnsmasq (run by `virtnetworkd`) answers only for guests on this network.

#### Scenario: Domain resolution

- **WHEN** the guest resolves its own hostname via DHCP-provided DNS
- **THEN** the query is answered from the local domain, with no external recursion path

### Requirement: Addressing and DHCP

The network SHALL assign the host side the gateway address `192.168.123.1/24` and serve DHCP in the range `192.168.123.100–254`.

#### Scenario: Guest obtains an address

- **WHEN** a guest with the reserved MAC boots and requests a lease
- **THEN** dnsmasq assigns `192.168.123.50`

#### Scenario: Unreserved client

- **WHEN** a client with an unreserved MAC requests a lease
- **THEN** it receives an address from the dynamic range `192.168.123.100–254`

### Requirement: Static DHCP reservation

The network SHALL bind MAC `52:54:00:aa:bb:01` to the fixed address `192.168.123.50`, named after the guest hostname, so the VM's address is stable across reboots.

#### Scenario: Reboot with fixed MAC

- **WHEN** the VM reboots with its fixed MAC
- **THEN** it receives the same `192.168.123.50` address

### Requirement: Host boot persistence

The network SHALL be marked autostart so that it is recreated automatically when the host reboots.

#### Scenario: Host reboot

- **WHEN** the host reboots
- **THEN** the host-only network and bridge are restored without manual intervention
