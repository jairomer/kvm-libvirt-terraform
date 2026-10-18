# Host-only network: a libvirt-managed bridge with NO `forward` block.
# That absence is what keeps the VM reachable only from this host (no NAT,
# no route to the LAN). Guest-to-guest traffic is left enabled.
resource "libvirt_network" "localhost" {
  name      = var.network_name
  autostart = true

  bridge = {
    name = var.bridge_name
    stp  = "on"
  }

  domain = {
    name       = var.network_name
    local_only = "yes"
  }

  ips = [
    {
      address = var.gateway_ip
      netmask = var.netmask
      dhcp = {
        ranges = [{ start = var.dhcp_start, end = var.dhcp_end }]
        hosts  = [{ mac = var.mac_address, name = var.hostname, ip = var.static_ip }]
      }
    }
  ]
}
