variable "remote_exec_script" {}
variable "remote_exec_script_args" {}
variable "dns_servers" { type = "list" }
variable "gateway" {}
variable "datacenter" {}         
variable "vsphere_user" {}
variable "vsphere_password" {}
variable "vsphere_server" {}
variable "hostname_prefix" {}
variable "ip_address" {}
variable "memory" {}

# Configure the VMware vSphere Provider
provider "vsphere" {
  user                 = "${var.vsphere_user}"
  password             = "${var.vsphere_password}"
  vsphere_server       = "${var.vsphere_server}"
  allow_unverified_ssl = true
}

resource "vsphere_virtual_machine" "agent" {
  count        = "1"
  name         = "${var.hostname_prefix}"
  vcpu         = 1
  memory       = "${var.memory}"
  datacenter   = "${var.datacenter}"
  dns_servers  = "${var.dns_servers}"

  network_interface {
    label              = "VM Network"
    ipv4_address       = "${var.ip_address}"
    ipv4_prefix_length = "24"
    ipv4_gateway       = "${var.gateway}"
  }

  disk {
    type     = "thin" 
    template = "rhel-server-7.3-x86_64_vanilla" 
    datastore = "default"
  }
  
  ### Environment specific stuff...
  provisioner "remote-exec" { ### add route back to vpn
    inline = [
      "ip route add 10.8.0.0/24 via 192.168.0.1",
    ]
  }
  ###

  connection {
    type     = "ssh"
    user     = "root"
    password = "root"
  }

}
