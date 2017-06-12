variable "datacenter" {}         
variable "vsphere_user" {}
variable "vsphere_password" {}
variable "vsphere_server" {}
variable "template" { type = "string" default = "rhel-server-7.3-x86_64_vmtools" }
variable "memory_mb" { type = "string" default = "2000" }
variable "vcpu_count" { type = "string" default = "1" }
variable "vm_network" { type = "string" default = "VM Network" }
variable "ipv4_address" {}
variable "ipv4_gateway" {}
variable "dns_servers" { type = "list" }
variable "ssh_username" {}
variable "ssh_password" {}
variable "hostname" {}

variable "yumrepo_baseurl" {}

# Configure the VMware vSphere Provider
provider "vsphere" {
  user                 = "${var.vsphere_user}"
  password             = "${var.vsphere_password}"
  vsphere_server       = "${var.vsphere_server}"
  allow_unverified_ssl = true
}

resource "vsphere_virtual_machine" "repohost" {
  name         = "${var.hostname}"
  vcpu         = "${var.vcpu_count}"
  memory       = "${var.memory_mb}"
  datacenter   = "${var.datacenter}"
  dns_servers  = "${var.dns_servers}"

  network_interface {
    label              = "${var.vm_network}"
    ipv4_address       = "${var.ipv4_address}"
    ipv4_prefix_length = "24"
    ipv4_gateway       = "${var.ipv4_gateway}"
  }

  disk {
    type     = "thin" 
    template = "${var.template}"
  }
  
  connection {
    type     = "ssh"
    user     = "root"
    password = "root"
  }

  ### Environment specific stuff...
  provisioner "remote-exec" { ### add route back to vpn
    inline = [
      "ip route add 10.8.0.0/24 via 192.168.0.1",
    ]
  }
  ###
  
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /var/www/html",
    ]
  }

  provisioner "file" {
    source      = "../repohost_webroot/"
    destination = "/var/www/html"
  }
  
  provisioner "file" {
    source      = "scripts"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    inline = [
      ". /tmp/scripts/configure_yumrepo.sh ${var.yumrepo_baseurl}",
      ". /tmp/scripts/deploy_repohost.sh",
    ]
  }

}
