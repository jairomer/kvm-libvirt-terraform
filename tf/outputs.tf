# The domain exposes no IP attribute; resolve it from the DHCP lease.
data "libvirt_domain_interface_addresses" "vm" {
  domain = libvirt_domain.vm.name
  source = "lease"
}

output "vm_ip" {
  description = "DHCP address assigned to the guest on the host-only bridge."
  value       = try(data.libvirt_domain_interface_addresses.vm.interfaces[0].addrs[0].addr, null)
}

output "ssh_command" {
  description = "Ready-to-run SSH command (valid from this host only)."
  value = format(
    "ssh -i %s -o IdentitiesOnly=yes %s@%s",
    trimsuffix(var.ssh_public_key_path, ".pub"),
    var.guest_user,
    try(data.libvirt_domain_interface_addresses.vm.interfaces[0].addrs[0].addr, "<pending>"),
  )
}
