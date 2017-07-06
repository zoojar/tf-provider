
variable "datacenter"         {}         
variable "vsphere_user"       {}
variable "vsphere_password"   {}
variable "vsphere_server"     {}
variable "template"           { type = "string" default = "rhel-server-7.3-x86_64_vmtools" }
variable "memory_mb"          { type = "string" default = "2000" }
variable "vcpu_count"         { type = "string" default = "2" }
variable "vm_network"         { type = "string" default = "VM Network" }
variable "ipv4_address"       {}
variable "ipv4_prefix_length" { type = "string" default = "24" }
variable "ipv4_gateway"       {}
variable "dns_servers"        { type = "list" }
variable "ssh_username"       {}
variable "ssh_password"       {}
variable "hostname"           {}

variable "yumrepo_baseurl"        {}
variable "puppetserver_fqdn"      {}
variable "puppetserver_ip"        {}
variable "psk"                    {}
variable "role"                   {}
variable "init_script"            { type = "string" default = "ls" }

# Configure the VMware vSphere Provider
provider "vsphere" {
  user                 = "${var.vsphere_user}"
  password             = "${var.vsphere_password}"
  vsphere_server       = "${var.vsphere_server}"
  allow_unverified_ssl = true
}

resource "vsphere_virtual_machine" "agent" {
  name         = "${var.hostname}"
  vcpu         = "${var.vcpu_count}"
  memory       = "${var.memory_mb}"
  datacenter   = "${var.datacenter}"
  dns_servers  = "${var.dns_servers}"

  network_interface {
    label              = "${var.vm_network}"
    ipv4_address       = "${var.ipv4_address}"
    ipv4_prefix_length = "${var.ipv4_prefix_length}"
    ipv4_gateway       = "${var.ipv4_gateway}"
  }

  disk {
    type      = "thin" 
    template  = "${var.template}" 
    datastore = "default"
  }

  connection {
    type     = "ssh"
    user     = "root"
    password = "root"
  }

  ### Environment specific stuff...
  provisioner "remote-exec" { ### block internet & add route back to vpn
    inline = [
      "route add default gw 192.168.0.2",
      "ip route add 10.8.0.0/24 via 192.168.0.1",
    ]
  }
  ###

  provisioner "file" {
    source      = "scripts"
    destination = "/tmp"
  }
  
  provisioner "remote-exec" {
    inline = [
      "${var.init_script}",
      ". /tmp/scripts/configure_yumrepo.sh ${var.yumrepo_baseurl}",
      ". /tmp/scripts/set_etc_hosts.sh ${var.puppetserver_ip} ${var.puppetserver_fqdn}",
      ". /tmp/scripts/install_puppetagent.sh --puppetserver_fqdn=${var.puppetserver_fqdn} --psk=${var.psk} --role=${var.role}",
    ]
  }

}
