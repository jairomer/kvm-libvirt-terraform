# libvirt OpenTofu: Host-Only Alpine VM

This project provisions an Alpine Linux VM on libvirt using OpenTofu, with SSH configured via cloud-init and the VM isolated on a host-only bridge (no NAT/uplink). The stack is minimal, reproducible, and pinned to a specific libvirt provider version.

## Architecture

![Architecture](docs/architecture.svg)

> Source: [`docs/architecture.mmd`](docs/architecture.mmd) — regenerate with `npx @mermaid-js/mermaid-cli -i docs/architecture.mmd -o docs/architecture.svg`

## Components

| Component | File(s) | Purpose |
|---|---|---|
| Provider | `providers.tf` | Pins `dmacvicar/libvirt` 0.9.9 and sets `uri = var.libvirt_uri` to `qemu:///system?socket=/run/libvirt/virtqemud-sock` (modular daemons; no monolithic libvirtd socket). |
| Host bootstrap | `day0.sh` | Idempotent Day-0 script: installs required packages (qemu/libvirt/dnsmasq/virt-install), enables modular libvirt sockets (`virtqemud`, `virtnetworkd`, `virtstoraged`, `virtlogd`, `virtlockd`), adds the invoking user to `libvirt` group, ensures the `default` storage pool exists. |
| Variables | `variables.tf` | Inputs: libvirt URI, hostname, guest user (`synk`), SSH public key path (`~/.ssh/id_ed25519.pub`), pool, base image URL, disk/memory/vCPU, network/bridge/subnet/DHCP/static IP/MAC. Reads SSH pubkey via `local.ssh_public_key`. |
| Network | `network.tf` | Defines `libvirt_network.localhost` as **host-only** (no `forward` block). Creates bridge `virbr-tofu` with domain `tofu-localhost`, local-only routing, static DHCP reservation binding `52:54:00:aa:bb:01` → `192.168.123.50`, DHCP range `192.168.123.100-254`, gateway `192.168.123.1/24`. |
| Storage volumes | `volumes.tf` | `base` downloads Alpine `alpine-3.22.6-x86_64-bios-cloudinit-r0.qcow2` into the pool. `root` is a 10GB CoW overlay (qcow2) backed by `base`. `libvirt_cloudinit_disk.init` generates NoCloud seed (user-data, meta-data, network-config). `cloudinit` volume uploads the ISO; **target.format.type is not pinned** (auto-detects `iso`) to avoid provider inconsistent-apply errors. |
| Domain | `domain.tf` | `libvirt_domain.vm` (KVM, q35, hvm) with `features = { acpi = true, apic = {} }` (required for virtio PCI power-up under q35/SeaBIOS), 1GB RAM, 2 vCPUs, `boot_devices = [{ dev = "hd" }]`. Disks: `vda` virtio-blk qcow2 (root), `sda` sata cdrom (cloudinit ISO, read-only). NIC `virtio-net` on the host-only network with fixed MAC, `wait_for_ip` from lease (timeout 300s), `running = true`. |
| Cloud-init | `cloud-init.yaml.tftpl` | Cloud-config: sets hostname/fqdn, creates `synk` in `wheel`, shell `/bin/ash`, `lock_passwd: false`, injects SSH pubkey. Disables password auth and root login; writes `sshd_config.d/60-cloud.conf`. Ensures `usermod -p '*' ${guest_user}` (unlocks account so Alpine OpenSSH with `UsePAM no` accepts pubkey). Enables/restarts sshd. NoCloud datasource (cidata) supplies meta-data, user-data, network-config v2 (eth0 dhcp4). |
| Outputs | `outputs.tf` | Resolves guest IP from DHCP lease via `libvirt_domain_interface_addresses.vm` (source="lease") and emits `vm_ip` plus `ssh_command` (`ssh -i <privkey> -o IdentitiesOnly=yes synk@<ip>`). |

## Deployment Flow

![Deployment Flow](docs/deployment-flow.svg)

> Source: [`docs/deployment-flow.mmd`](docs/deployment-flow.mmd) — regenerate with `npx @mermaid-js/mermaid-cli -i docs/deployment-flow.mmd -o docs/deployment-flow.svg`

## Specs

Intended behavior is codified in [`specs/`](specs/), one specification per capability:

| Spec | Covers |
|---|---|
| [`host-bootstrap`](specs/host-bootstrap/spec.md) | `day0.sh`: packages, daemons, libvirt group, default pool |
| [`host-only-network`](specs/host-only-network/spec.md) | Isolated bridge, DHCP, static reservation |
| [`storage`](specs/storage/spec.md) | Base image, CoW root overlay, cloud-init seed ISO |
| [`domain`](specs/domain/spec.md) | KVM q35 machine, ACPI/APIC, disks, NIC |
| [`guest-cloud-init`](specs/guest-cloud-init/spec.md) | User creation, key injection, sshd hardening |
| [`connectivity`](specs/connectivity/spec.md) | Lease-based outputs, key-only SSH, isolation |
| [`state`](specs/state/spec.md) | Local state, gitignored, re-apply recovery |

Each spec uses OpenSpec format (`Purpose` → `Requirements` → `Scenarios`) and is the source of truth for what the stack is supposed to do.

## Key Design Notes

- **Host-only isolation**: No `forward` block in the libvirt network → no NAT/uplink; only reachable from the host. Guest-to-guest traffic allowed.
- **Modular libvirt on Tumbleweed**: Uses `qemu:///system?socket=/run/libvirt/virtqemud-sock` (not `/run/libvirt/libvirt-sock`).
- **Provider/version pinning**: `dmacvicar/libvirt` 0.9.9 with locked hashes in `.terraform.lock.hcl`.
- **Boot stability (q35 + SeaBIOS)**: Explicit `features = { acpi = true, apic = {} }` to avoid virtio PCI D3cold→D0 power-up issues.
- **Cloud-init seed**: No pinned `target.format.type = "raw"` on the cloudinit volume; auto-detect `iso` for cidata.
- **Key-only SSH, unlocked account**: Alpine OpenSSH (UsePAM no) rejects locked accounts; set `lock_passwd: false` and `usermod -p '*' ${guest_user}`.
- **Lease-based IP discovery**: IP resolved via `libvirt_domain_interface_addresses` with `source = "lease"`.
- **Pristine root**: CoW overlay on base; replacing root yields clean first-boot/cloud-init.

## Quick Start

1. Bootstrap host: `cd tf && sudo ./day0.sh` (re-login after adding user to `libvirt`)
2. Initialize: `tofu init`
3. Review: `tofu plan`
4. Provision: `tofu apply`
5. Connect: `ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes synk@$(tofu output -raw vm_ip)`
6. Teardown: `tofu destroy`
