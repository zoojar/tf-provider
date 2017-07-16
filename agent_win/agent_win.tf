
variable "datacenter"         {}         
variable "vsphere_user"       {}
variable "vsphere_password"   {}
variable "vsphere_server"     {}
variable "template"           { type = "string" default = "win_2012_r2_x64" }
variable "memory_mb"          { type = "string" default = "2000" }
variable "vcpu_count"         { type = "string" default = "2" }
variable "vm_network"         { type = "string" default = "VM Network" }
variable "ipv4_address"       {}
variable "ipv4_prefix_length" { type = "string" default = "24" }
variable "ipv4_gateway"       {}
variable "dns_servers"        { type = "list" }
variable "winrm_username"     { type = "string" default = "Administrator" }
variable "winrm_password"     { type = "string" default = "Adm!n!strat0r" }
variable "hostname"           {}

variable "puppetserver_fqdn"      {}
variable "puppetserver_ip"        {}
variable "repohost_fqdn"          {}
variable "repohost_ip"            {}
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
    type     = "winrm"
    user     = "${var.winrm_username}"
    password = "${var.winrm_password}"
  }

  ### Environment specific stuff...
  #provisioner "remote-exec" { ### block internet & add route back to vpn
  #  inline = [
  #    "route add default gw 192.168.0.2",
  #    "ip route add 10.8.0.0/24 via 192.168.0.1",
  #  ]
  #}
  ###

  provisioner "file" {
    source      = "scripts"
    destination = "/tmp"
  }
  
  provisioner "remote-exec" {
    inline = [
      "echo \"${var.puppetserver_ip} ${var.puppetserver_fqdn}\" >> c:\\windows\\system32\\drivers\\etc\\hosts",
      "mkdir c:\\programdata\\puppetlabs\\puppet\\etc",
      "cmd /c echo set-content c:\\Programdata\\PuppetLabs\\Puppet\\etc\\csr_attributes.yaml \"custom_attributes:\`r\`n 1.2.840.113549.1.9.7: ${var.psk}\`r\`nextension_requests:\`r\`n  pp_role: ${var.role}\`r\`n\" ",
      "echo wget http://${var.repohost_ip}/repo/win/puppet-agent-1.4.2-x64.msi -outfile c:\\windows\\temp\\puppet-enterprise-installer.msi",
      "Start-Process -FilePath msiexec -ArgumentList /i, c:\\Windows\\temp\\puppet-enterprise-installer.msi, PUPPET_MASTER_SERVER=${var.puppetserver_fqdn}, /quiet",
    ]
  }


}
