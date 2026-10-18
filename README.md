# libvirt OpenTofu: Host-Only Alpine VM

This project provisions an Alpine Linux VM on libvirt using OpenTofu, with SSH configured via cloud-init and the VM isolated on a host-only bridge (no NAT/uplink). The stack is minimal, reproducible, and pinned to a specific libvirt provider version.

## Architecture

```mermaid
graph TB
    subgraph Host [Host OS (openSUSE Tumbleweed)]
        subgraph Libvirt[libvirt - Modular Daemons]
            VQ[virtqemud.socket]
            VN[virtnetworkd]
            VS[virtstoraged]
            VL[virtlogd/virtlockd]
        end

        subgraph OTF[OpenTofu]
            TF[tf/*.tf]
            Prov[provider: dmacvicar/libvirt 0.9.9]
            State[terraform.tfstate]
        end

        subgraph Net[Host-Only Network]
            BR[virbr-tofu bridge<br/>192.168.123.1/24]
            DNS[dnsmasq via virtnetworkd]
        end

        subgraph Pool[Storage Pool default]
            Base[base qcow2 - Alpine cloud image]
            Root[root qcow2 - CoW overlay]
            CI[cloudinit.iso - cidata seed]
        end

        Day0[day0.sh - Host bootstrap]
    end

    subgraph Guest[Alpine Linux VM]
        VM[tofu-vm<br/>KVM, q35, virtio]
        SSHD[sshd - key-only auth]
        User[synk (wheel), SSH ed25519 key]
    end

    Day0 -->|installs pkgs, enables daemons,<br/>adds user to libvirt, ensures pool| Host
    TF -->|plan/apply| Prov
    Prov -->|libvirt API over qemu:///system?socket=/run/libvirt/virtqemud-sock| VQ
    VQ --> VN & VS
    VN -->|defines/manages| Net
    VS -->|manages volumes| Pool
    Prov -->|creates network, volumes, domain| Net
    Prov -->|creates base/root/cloudinit| Pool
    Base -.CoW backing.-> Root
    CI -->|cloud-init NoCloud (cidata)| VM
    Net -->|host-only bridge, static DHCP (52:54:00:aa:bb:01 -> 192.168.123.50)| VM
    VM -->|boots from root (vda)| Root
    VM -->|mounts cidata as cdrom (sda)| CI
    CI -->|cloud-config: creates user, injects key, configures sshd, unlocks account| User
    SSHD -->|listens on 0.0.0.0:22| VM
    Host -.SSH (key-only).-> VM
```

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

```mermaid
flowchart LR
    A[Day 0: sudo ./day0.sh] --> B[Host ready: daemons, libvirt group, default pool]
    B --> C[tofu init]
    C --> D[tofu plan]
    D --> E[tofu apply]
    E --> F[Network created]
    E --> G[Volumes: base/root/cloudinit ISO]
    E --> H[Domain created & boots]
    H --> I[Cloud-init runs (NoCloud)]
    I --> J[User synk created, keys injected, sshd configured]
    I --> K[Guest gets static lease 192.168.123.50]
    J --> L[SSH: ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes synk@192.168.123.50]
```

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
