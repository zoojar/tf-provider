 #install_puppet_agent.ps1 
param (
  [string]$puppet_master_server = $(throw "-puppet_master_server is required."),
  [string]$installer_url = $(throw "-installer_url is required."),
  [string]$role = $(throw "-role is required."),
  [string]$psk = $(throw "-psk is required.")
)

mkdir c:\programdata\puppetlabs\puppet\etc
set-content c:\Programdata\PuppetLabs\Puppet\etc\csr_attributes.yaml "custom_attributes:`r`n 1.2.840.113549.1.9.7: $psk`r`nextension_requests:`r`n  pp_role: $role`r`n"
wget $installer_url -outfile c:\\windows\\temp\\puppet-enterprise-installer.msi
$msiexec_path = "C:\Windows\System32\msiexec.exe"
$msiexec_args = "/qn /log c:\\windows\\temp\\puppet-enterprise-installer.log /i c:\\windows\\temp\\puppet-enterprise-installer.msi PUPPET_MASTER_SERVER=${puppet_master_server}"
$msiexec_proc = [System.Diagnostics.Process]::Start($msiexec_path, $msiexec_args)
$msiexec_proc.WaitForExit()