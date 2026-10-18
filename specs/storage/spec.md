# Storage Specification

## Purpose

Define the volumes backing the VM: a pristine base cloud image, a copy-on-write root overlay, and the cloud-init seed ISO, all within the `default` storage pool.

## Requirements

### Requirement: Pinned base image

The base volume SHALL be the pinned Alpine 3.22.6 x86_64 BIOS cloudinit qcow2 image, downloaded from the Alpine CDN into the pool by the provider. The base image SHALL remain unmodified for the lifetime of the root overlay.

#### Scenario: First apply

- **WHEN** the stack is applied and the base volume does not exist
- **THEN** the pinned qcow2 is downloaded into the `default` pool

#### Scenario: Base stays pristine

- **WHEN** the guest writes to its root disk
- **THEN** writes land in the overlay only; the base qcow2 is unchanged

### Requirement: Copy-on-write root overlay

The root volume SHALL be a qcow2 overlay of `disk_size_gb` (default 10 GiB) capacity backed by the base image. The base SHALL be referenced as a backing store, not copied.

#### Scenario: Root creation

- **WHEN** the root volume is created
- **THEN** it is a qcow2 volume with the base image as its backing file and the configured capacity

#### Scenario: Rebuild from pristine base

- **WHEN** the root volume is destroyed and re-applied
- **THEN** the new root starts from the pristine base with first-boot cloud-init behavior

### Requirement: Cloud-init seed generation

A NoCloud seed SHALL be generated containing user-data (from `cloud-init.yaml.tftpl`), meta-data (instance-id and local-hostname), and network-config v2 requesting DHCP4 on eth0.

#### Scenario: Seed contents

- **WHEN** the seed is generated
- **THEN** the cidata volume contains user-data, meta-data, and network-config files matching the template and variables

#### Scenario: Variable-driven customization

- **WHEN** hostname, guest user, or SSH public key variables change
- **THEN** the regenerated seed reflects the new values on the next apply

### Requirement: Seed uploaded as ISO with auto-detected format

The generated seed SHALL be uploaded into the pool as a volume named `<hostname>-cloudinit.iso`. The volume's target format SHALL NOT be pinned; the provider auto-detects `iso`. Pinning a format is prohibited because it triggers a provider "inconsistent result after apply" error.

#### Scenario: Upload on apply

- **WHEN** the stack is applied
- **THEN** the seed ISO is uploaded to the pool and attached to the domain as a cdrom

#### Scenario: Format left unpinned

- **WHEN** the seed volume is defined
- **THEN** no explicit target format is set, and apply completes without an inconsistent-result error

### Requirement: Pool placement

All volumes (base, root, cloud-init ISO) SHALL live in the configured storage pool (default `default`).

#### Scenario: Non-default pool

- **WHEN** the pool variable is set to another pool name
- **THEN** all volumes are created in that pool
