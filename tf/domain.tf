resource "libvirt_domain" "vm" {
  name        = var.hostname
  type        = "kvm"
  memory      = var.memory_mb
  memory_unit = "MiB"
  vcpu        = var.vcpu

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [{ dev = "hd" }]
  }

  # ACPI must be enabled explicitly. If `features` is omitted the provider emits
  # a domain without <features>, ACPI stays off, and the guest kernel cannot
  # power up the virtio PCI devices ("Unable to change power state from D3cold
  # to D0, device inaccessible") -> root is never found and the VM hangs.
  features = {
    acpi = true
    apic = {}
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = var.pool
            volume = libvirt_volume.root.name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
        driver = {
          type = "qcow2"
        }
      },
      {
        device    = "cdrom"
        read_only = true
        source = {
          volume = {
            pool   = var.pool
            volume = libvirt_volume.cloudinit.name
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
      },
    ]

    interfaces = [
      {
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = libvirt_network.localhost.name
          }
        }
        mac = {
          address = var.mac_address
        }
        wait_for_ip = {
          network = var.subnet_cidr
          source  = "lease"
          timeout = 300
        }
      },
    ]
  }

  running = true
}
