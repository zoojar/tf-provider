#!/bin/bash
# Deploy script for Proxy server, installs, configures & starts HAProxy

#Defaults:
log_file='/tmp/deploy_proxy.log'
puppet_package='puppet-agent'
deploy_proxy_pp='/tmp/deploy_proxy.pp'
tmp_puppet_modules='/tmp/puppet_modules'
stats_port='8101'
read -d '' puppet_modules <<'EOF'
puppetlabs-stdlib-4.17.0.tar.gz
puppetlabs-haproxy-1.5.0.tar.gz
puppetlabs-concat-2.2.1.tar.gz
puppetlabs-firewall-1.8.2.tar.gz
herculesteam-augeasproviders_core-2.1.3.tar.gz
herculesteam-augeasproviders_sysctl-2.2.0.tar.gz
puppet-selinux-1.1.0.tar.gz
EOF

while test $# -gt 0; do
        case "$1" in
                -h|--help)
                        echo "options:"
                        echo "-h, --help                        Show help."
                        echo "-m, --puppet_modules_baseurl      Base URL for downloading Puppet modules, example: http://repohost.local/puppet_modules"
                        echo "-p, --proxy_members_pp            HAProxy Memnber Puppet Config"
                        exit 0
                        ;;
                -m)
                        shift
                        if test $# -gt 0; then
                                puppet_modules_baseurl=$1
                        else
                                echo "ERROR: --puppet_modules_baseurl|-m NOT specified."
                                exit 1
                        fi
                        shift
                        ;;
                --puppet_modules_baseurl*)
                        puppet_modules_baseurl=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift
                        ;;  
                *)
                        break
                        ;;
        esac
done

firewall_default_zone=`firewall-cmd --get-default-zone`
echo "$(date) INFO: Configuring firewall: Opening ports 80, 443 & 22 for the default zone: ${firewall_default_zone}..." | tee -a  $log_file
firewall-cmd --permanent --zone=$firewall_default_zone --add-port=80/tcp
firewall-cmd --permanent --zone=$firewall_default_zone --add-port=443/tcp
firewall-cmd --permanent --zone=$firewall_default_zone --add-port=22/tcp
firewall-cmd --reload

echo "$(date) INFO: Installing [$puppet-agent] via YUM..." | tee -a  $log_file
yum install -y $puppet_package
export PATH="$PATH:/opt/puppetlabs/bin"

echo "$(date) INFO: Downloading & installing Puppet modules from [$puppet_modules_baseurl]" | tee -a  $log_file
puppet resource file $tmp_puppet_modules ensure=directory
IFS=$'\n'
for module in $puppet_modules ; do
  puppet resource file $tmp_puppet_modules/$module ensure=file source=$puppet_modules_baseurl/$module
  puppet module install $tmp_puppet_modules/$module --ignore-dependencies
done


echo "$(date) INFO: Deploying HAProxy via Puppet..." | tee -a  $log_file
cat >$deploy_proxy_pp <<EOF
  sysctl { 'net.ipv4.ip_nonlocal_bind':    value => '1', }
  sysctl { 'net.ipv4.ip_local_port_range': value => '1024 65023', }
  selinux::boolean { 'httpd_can_network_connect': }
  selinux::boolean { 'haproxy_connect_any': }

  class { 'haproxy': 
    require => Sysctl['net.ipv4.ip_nonlocal_bind','net.ipv4.ip_local_port_range'],
  }

  define member (
    String \$service = \$title,
    String \$ip,
    String \$fqdn = \$title,
    String \$port,
    String \$mode,    
  ){
    haproxy::listen { "\${service}":
      mode             => \$mode,
      collect_exported => false,
      ipaddress        => \$::ipaddress,
      ports            => \$port,
    }
    haproxy::balancermember { "\${service}_01":
      listening_service => \$service,
      server_names      => \$fqdn,
      ipaddresses       => \$ip,
      ports             => \$port,
      options           => 'check',
    }
  }
  
  member { 'puppetserver.vsphere.local':  ip => '192.168.0.160', port => '8140', mode => 'tcp', }
  member { 'repohost.vsphere.local':  ip => '192.168.0.162', port => '80', mode => 'http', }
  member { 'gemhost.vsphere.local':  ip => '192.168.0.162', fqdn => 'repohost.vsphere.local', port => '81', mode => 'http', }

  haproxy::listen { 'stats':
    mode      => 'http',
    ports     => '$stats_port',
    ipaddress => \$::ipaddress,
    options   => {
      'stats' => [
        'enable',
        'hide-version',
        'realm HAProxy\ Statistics',
        'uri /stats',
      ]
    },
  }
  
  class {'firewall':
    ensure => stopped,
  }
EOF
export PATH="/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:/opt/puppet/bin:$PATH"
puppet apply $deploy_proxy_pp -v


