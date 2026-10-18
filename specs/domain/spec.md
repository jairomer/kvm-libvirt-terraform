# Domain Specification

## Purpose

Define the VM domain: machine type, firmware features, disks, NIC, and power state as managed by the libvirt provider.

## Requirements

### Requirement: KVM q35 machine

The domain SHALL be a KVM virtual machine of type `hvm`, architecture `x86_64`, machine `q35`, booting from disk (`hd`).

#### Scenario: Domain creation

- **WHEN** the stack is applied
- **THEN** the domain exists as a q35 KVM guest configured to boot from the root disk

### Requirement: Explicit ACPI and APIC features

The domain SHALL explicitly enable `acpi` and `apic` features. Omitting them is prohibited: without ACPI the guest kernel cannot power up virtio PCI devices from D3cold to D0, the root disk is never found, and the VM hangs.

#### Scenario: Features present

- **WHEN** the domain XML is generated
- **THEN** it contains `<features>` with ACPI and APIC enabled

#### Scenario: Guest boots to userspace

- **WHEN** the domain starts with these features
- **THEN** virtio devices power up normally and the guest finds its root disk

### Requirement: Resource sizing

The domain SHALL have the configured memory (default 1024 MiB) and vCPU count (default 2).

#### Scenario: Custom sizing

- **WHEN** the memory or vcpu variables change
- **THEN** the domain is resized on the next apply

### Requirement: Root disk attachment

The root volume SHALL be attached as `vda` on the virtio bus with the qcow2 driver type.

#### Scenario: Boot device

- **WHEN** the domain starts
- **THEN** the guest sees its root filesystem on a virtio-blk device at `vda`

### Requirement: Cloud-init cdrom attachment

The cloud-init ISO SHALL be attached as `sda` on the SATA bus, as a read-only cdrom.

#### Scenario: cidata visible to guest

- **WHEN** the domain boots
- **THEN** the guest mounts the seed as a cdrom and cloud-init finds the NoCloud datasource

### Requirement: Host-only NIC with fixed MAC

A virtio NIC SHALL attach to the host-only network with the fixed MAC `52:54:00:aa:bb:01`, matching the static DHCP reservation.

#### Scenario: NIC on apply

- **WHEN** the domain is created
- **THEN** the guest has a virtio-net interface on the host-only bridge with the reserved MAC

### Requirement: Wait for lease-based address

Domain creation SHALL block until the guest reports an address from a DHCP lease within the configured subnet, with a 300-second timeout.

#### Scenario: Address acquired

- **WHEN** the guest requests and receives its lease
- **THEN** apply proceeds with the address known

#### Scenario: Timeout

- **WHEN** no lease is obtained within the timeout
- **THEN** apply fails rather than silently completing without an address

### Requirement: Power on apply

The domain SHALL be started (`running = true`) as part of apply.

#### Scenario: Fresh apply

- **WHEN** the stack is applied
- **THEN** the VM is running and cloud-init executes on first boot
