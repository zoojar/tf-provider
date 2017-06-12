#!/bin/bash
#Bootstrap repohost on CentOS 7
log_file='/var/log/bootstrap_repohost.log'
webroot='/var/www/html'
read -r -d '' puppet_modules << EOV
puppetlabs-stdlib-4.17.0.tar.gz,
puppetlabs-firewall-1.8.2.tar.gz,
palli-createrepo-2.1.0.tar.gz,
puppetlabs-apache-1.11.0.tar.gz,
puppetlabs-concat-2.2.1.tar.gz
EOV
tmp_dir='/tmp/install_repohost_tmp'
mod_dir="${webroot}/puppet_modules"
puppet_bin='/opt/puppetlabs/bin/puppet'

echo "$(date) Installing wget..." | tee -a  $log_file
yum install -y wget

echo "$(date) Preparing temporary working directory..." | tee -a  $log_file
mkdir -p $tmp_dir
cd $tmp_dir

echo "$(date) Installing puppet agent..." | tee -a  $log_file
yum -y install puppet

echo "$(date) Installing puppet modules from ${mod_dir}..." | tee -a  $log_file
echo $puppet_modules | sed -n 1'p' | tr ',' '\n' | while read module; do
    $puppet_bin module install $mod_dir/$module --ignore-dependencies --force
done
echo "$(date) Preparing ${tmp_dir}/repohost.pp..." | tee -a  $log_file
cat <<'EOF' > $tmp_dir/repohost.pp
  file { ['/var/cache/repo','/var/www/html/repo']:
    ensure => directory,
  }

  package { 'yum-utils':
    ensure => '1.1.31-40.el7',
  }
  
  createrepo { 'yumrepo':
    repository_dir => "/var/www/html/repo/yumrepos",
    repo_cache_dir => '/var/cache/repo/yumrepos',
    require        => [ 
      File['/var/cache/repo'],
    ]
  }

  exec { 'restorecon':
    subscribe => Createrepo['yumrepo'],
    command   => 'restorecon -r /var/www/html',
    path      => '/usr/sbin/',
  }

  class { 'apache': }
  
  class {'firewall':
    ensure => stopped,
  }
  
  firewall { '80 accept tcp dport 80':
    proto  => 'tcp',
    dport  => 80,
    action => 'accept',
  }
EOF

echo "$(date) Applying ${tmp_dir}/repohost.pp..." | tee -a  $log_file
$puppet_bin apply $tmp_dir/repohost.pp -v
