variable "datacenter"             {}         
variable "vsphere_user"           {}
variable "vsphere_password"       {}
variable "vsphere_server"         {}
variable "template"               { type = "string" default = "rhel-server-7.3-x86_64_vmtools" }
variable "memory_mb"              { type = "string" default = "4000" }
variable "vcpu_count"             { type = "string" default = "1" }
variable "vm_network"             { type = "string" default = "VM Network" }
variable "ipv4_address"           {}
variable "ipv4_prefix_length"     { type = "string" default = "24" }
variable "ipv4_gateway"           {}
variable "dns_servers"            { type = "list" }
variable "ssh_username"           {}
variable "ssh_password"           {}
variable "hostname"               {}
    
variable "yumrepo_baseurl"        {}
variable "psk"                    {}
variable "role"                   {}
variable "control_repo"           {}
variable "gem_source_url"         {}
variable "git_server"             {}
variable "git_server_ip"          {}
variable "git_user"               {}
variable "git_password"           {}
variable "puppet_modules_baseurl" {}
variable "puppet_codedir"         { type = "string" default = "/etc/puppetlabs/code" }
variable "repohost_fqdn"          { type = "string" default = "repohost.vsphere.local" }
variable "repohost_ip"            { type = "string" default = "192.168.0.162" }
variable "staging_code_dir"       { type = "string" default = "/tmp/control-repo-staging" }
variable "r10k_sshkey_file_content" { type = "string" default = "" }

# Configure the VMware vSphere Provider
provider "vsphere" {
  version              = "~> 0.4.2"
  user                 = "${var.vsphere_user}"
  password             = "${var.vsphere_password}"
  vsphere_server       = "${var.vsphere_server}"
  allow_unverified_ssl = true
}

resource "vsphere_virtual_machine" "puppetserver" {
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
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
  }
  
  ### Environment specific stuff...
  provisioner "remote-exec" { ### block internet & add route back to vpn
    inline = [
      "route add default gw 192.168.0.2",
      "ip route add 10.8.0.0/24 via 192.168.0.1",
      "mkdir -p /repobase",
    ]
  }
  ###

  provisioner "file" {
    source      = "scripts"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    inline = [
      ". /tmp/scripts/configure_yumrepo.sh ${var.yumrepo_baseurl}",
      "yum install -y puppetserver",
      "/opt/puppetlabs/bin/puppet resource host ${var.git_server} ip=${var.git_server_ip}", #fix for absence of dns.
      "/opt/puppetlabs/bin/puppet resource host ${var.repohost_fqdn} ip=${var.repohost_ip}", #fix for absence of dns. 
      ". /tmp/scripts/install_puppetagent.sh --puppetserver_fqdn=puppetserver.vsphere.local --psk=123 --role=${var.role}",
      "mkdir -p ${var.staging_code_dir}/",
    ]
  }

  provisioner "file" {
    source      = "../control-repo-staging/production/"
    destination = "${var.staging_code_dir}"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ${var.staging_code_dir}/scripts/*",
      "puppet resource file /etc/puppetlabs/r10k ensure=directory && puppet resource file /etc/puppetlabs/r10k/r10k_id_rsa mode='0400' content='${var.r10k_sshkey_file_content}'",
      "FACTER_staging_puppetserver=true /opt/puppetlabs/bin/puppet apply -e \"include roles::puppetserver\" --hiera_config=${var.staging_code_dir}/hiera.yaml --modulepath=${var.staging_code_dir}/site:${var.staging_code_dir}/site/profiles/files/puppetserver/r10k_module_dependencies:${var.staging_code_dir}/modules",
      "rm -rf /etc/puppetlabs/puppet/ssl",
      "rm -f /etc/puppetlabs/puppetserver/ssl/ca/signed/*.pem",
      "service puppetserver restart",
      "puppet agent -tv",
      "puppet agent -tv",
      "if [ $? == '2' ]; then exit 0 ; fi ",
    ]
  }
}