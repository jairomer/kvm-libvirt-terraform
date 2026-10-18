variable "libvirt_uri" {
  description = <<-EOT
    libvirt connection URI. openSUSE Tumbleweed uses modular daemons, so there is
    no /run/libvirt/libvirt-sock; point the local dialer at virtqemud's socket.
    On a monolithic libvirtd host, use "qemu:///system" instead.
  EOT
  type        = string
  default     = "qemu:///system?socket=/run/libvirt/virtqemud-sock"
}

variable "hostname" {
  description = "Guest hostname and libvirt domain name."
  type        = string
  default     = "tofu-vm"
}

variable "guest_user" {
  description = "Login user created inside the guest via cloud-init."
  type        = string
  default     = "synk"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key injected into the guest via cloud-init."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "pool" {
  description = "libvirt storage pool that holds all volumes."
  type        = string
  default     = "default"
}

variable "base_image_url" {
  description = "Cloud image the root volume is derived from; downloaded by the provider."
  type        = string
  default     = "https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/cloud/alpine-3.22.6-x86_64-bios-cloudinit-r0.qcow2"
}

variable "disk_size_gb" {
  description = "Root disk size in GiB."
  type        = number
  default     = 10
}

variable "memory_mb" {
  description = "Guest memory in MiB."
  type        = number
  default     = 1024
}

variable "vcpu" {
  description = "Number of guest vCPUs."
  type        = number
  default     = 2
}

# --- host-only bridge network (no `forward` block => isolated from the LAN) ---

variable "network_name" {
  description = "Name of the libvirt network backing the host-only bridge."
  type        = string
  default     = "tofu-localhost"
}

variable "bridge_name" {
  description = "Linux bridge device libvirt creates for the host-only network."
  type        = string
  default     = "virbr-tofu"
}

variable "gateway_ip" {
  description = "Host-side IP (default gateway) of the host-only network."
  type        = string
  default     = "192.168.123.1"
}

variable "netmask" {
  description = "IPv4 netmask of the host-only network."
  type        = string
  default     = "255.255.255.0"
}

variable "subnet_cidr" {
  description = "Host-only subnet in CIDR form, used to wait for the guest IP."
  type        = string
  default     = "192.168.123.0/24"
}

variable "dhcp_start" {
  description = "First address of the DHCP range."
  type        = string
  default     = "192.168.123.100"
}

variable "dhcp_end" {
  description = "Last address of the DHCP range."
  type        = string
  default     = "192.168.123.254"
}

variable "static_ip" {
  description = "Static DHCP address reserved for the guest (bound to var.mac_address)."
  type        = string
  default     = "192.168.123.50"
}

variable "mac_address" {
  description = "Fixed MAC address of the guest interface."
  type        = string
  default     = "52:54:00:aa:bb:01"
}

locals {
  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}
