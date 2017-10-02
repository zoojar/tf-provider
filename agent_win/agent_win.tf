
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
variable "powershell_cmd"         { type = "string" default = "powershell.exe -sta -ExecutionPolicy Unrestricted" }
variable "temp_path"              { type = "string" default = "c:\\windows\\temp" }
variable "domain"                 { type = "string" default = "vsphere.local" }

# Configure the VMware vSphere Provider
provider "vsphere" {
  user                 = "${var.vsphere_user}"
  password             = "${var.vsphere_password}"
  vsphere_server       = "${var.vsphere_server}"
  allow_unverified_ssl = true
}

resource "vsphere_virtual_machine" "agent_win" {
  name               = "${var.hostname}"
  vcpu               = "${var.vcpu_count}"
  memory             = "${var.memory_mb}"
  datacenter         = "${var.datacenter}"
  dns_servers        = "${var.dns_servers}"
  windows_opt_config = { admin_password = "Adm!n!strat0r" }

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
    host     = "${var.ipv4_address}"
    user     = "${var.winrm_username}"
    password = "${var.winrm_password}"
    timeout  = "15m"
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
    destination = "${var.temp_path}"
  }
  


  provisioner "remote-exec" {
    inline = [
      "echo ${var.puppetserver_ip} ${var.puppetserver_fqdn} >> c:\\windows\\system32\\drivers\\etc\\hosts",
      "; ${var.powershell_cmd} -Command \"& restart-computer\" ",
    ]
  }
  
  provisioner "local-exec" {
    command = "sleep 15"
  }

  provisioner "remote-exec" {
    inline = [
      "; ${var.powershell_cmd} -file ${var.temp_path}\\install_puppet_agent.ps1 -puppet_master_server ${var.puppetserver_fqdn} -installer_url http://${var.repohost_ip}/repo/win/puppet-agent-1.10.4-x64.msi -role roles::base_windows -psk 123 -puppet_agent_certname ${var.hostname}.${var.domain}",
      "; ${var.powershell_cmd} -command 'puppet agent -tv'"
    ]
  }


}
