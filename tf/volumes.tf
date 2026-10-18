# Base cloud image, fetched into the pool by the provider.
resource "libvirt_volume" "base" {
  name = "${var.hostname}-base.qcow2"
  pool = var.pool

  create = {
    content = {
      url = var.base_image_url
    }
  }

  target = {
    format = {
      type = "qcow2"
    }
  }
}

# Writable copy-on-write root disk, so the base image stays pristine.
resource "libvirt_volume" "root" {
  name     = "${var.hostname}-root.qcow2"
  pool     = var.pool
  capacity = var.disk_size_gb * 1024 * 1024 * 1024

  backing_store = {
    path = libvirt_volume.base.path
    format = {
      type = "qcow2"
    }
  }

  target = {
    format = {
      type = "qcow2"
    }
  }
}

# cloud-init seed (cidata ISO), generated from the template.
resource "libvirt_cloudinit_disk" "init" {
  name = "${var.hostname}-cloudinit"

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    hostname       = var.hostname
    guest_user     = var.guest_user
    ssh_public_key = local.ssh_public_key
  })

  meta_data = yamlencode({
    instance-id    = var.hostname
    local-hostname = var.hostname
  })

  network_config = <<-EOT
    version: 2
    ethernets:
      eth0:
        dhcp4: true
  EOT
}

# Upload the generated ISO into the pool so qemu can read it.
# Do NOT pin target.format.type here: the provider auto-detects "iso" for the
# seed image, and forcing "raw" triggers
# "provider produced inconsistent result after apply".
resource "libvirt_volume" "cloudinit" {
  name = "${var.hostname}-cloudinit.iso"
  pool = var.pool

  create = {
    content = {
      url = libvirt_cloudinit_disk.init.path
    }
  }
}
