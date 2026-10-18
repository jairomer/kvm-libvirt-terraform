# Connectivity Specification

## Purpose

Define how the host discovers and reaches the guest after apply, and the isolation guarantees that bound that connectivity.

## Requirements

### Requirement: Address output from DHCP lease

The stack SHALL expose the guest's address as an output, resolved from the DHCP lease via the libvirt domain interface-address query (`source = "lease"`). The domain resource exposes no address attribute directly, so the lease is the source of truth.

#### Scenario: Apply completes

- **WHEN** apply succeeds and the guest holds a lease
- **THEN** `tofu output -raw vm_ip` prints the guest's address (default `192.168.123.50`)

#### Scenario: No lease yet

- **WHEN** the lease has not yet been obtained
- **THEN** the output is null rather than an incorrect value

### Requirement: Ready-to-run SSH command

The stack SHALL emit an `ssh_command` output that runs key-only SSH to the guest using the private key corresponding to the configured public key, with `IdentitiesOnly=yes` to avoid agent-key interference.

#### Scenario: Copy-paste connect

- **WHEN** apply succeeds
- **THEN** running the emitted command from the host logs the guest user into the VM

### Requirement: Host-only reachability

The guest SHALL be reachable only from the host. There SHALL be no NAT, no LAN route, and no other ingress path; consequences of the host-only network requirement bound this guarantee.

#### Scenario: LAN cannot reach guest

- **WHEN** a machine on the host's LAN attempts to connect to the guest address
- **THEN** the connection fails because no route exists

### Requirement: Key-only authentication

Guest SSH SHALL accept public-key authentication only. Password and root logins are refused per the guest cloud-init specification; this requirement restates the connectivity consequence.

#### Scenario: Key-based login

- **WHEN** the host connects with the correct private key
- **THEN** login succeeds

#### Scenario: Password prompt never appears

- **WHEN** a client attempts SSH without a key
- **THEN** authentication fails without offering password auth
