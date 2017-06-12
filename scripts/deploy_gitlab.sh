#!/bin/bash
# Deploy script for Gitlab, installs, configures & starts Gitlab

#Terminate on error...
set -e

#Defaults:
log_file='/tmp/deploy_gitlab.log'
puppet_package='puppet-agent'
deploy_gitlab_pp='/tmp/deploy_gitlab.pp'
puppet_modules='puppetlabs-stdlib-4.17.0.tar.gz,vshn-gitlab-1.13.3.tar.gz'
tmp_puppet_modules='/tmp/puppet_modules'

while test $# -gt 0; do
        case "$1" in
                -h|--help)
                        echo "options:"
                        echo "-h, --help                        Show help."
                        echo "-m, --module_baseurl              Base URL for downloading Puppet modules, example: http://repohost.local/puppet_modules"
                        exit 0
                        ;;
                -m)
                        shift
                        if test $# -gt 0; then
                                puppet_modules_baseurl=$1
                        else
                                echo "ERROR: --module_baseurl|-m NOT specified."
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

firewall_default_zone=`sudo firewall-cmd --get-default-zone`
echo "$(date) INFO: Configuring firewall: Opening ports 80, 443 & 22 for the default zone: ${firewall_default_zone}..." | tee -a  $log_file
firewall-cmd --permanent --zone=$firewall_default_zone --add-port=80/tcp
firewall-cmd --permanent --zone=$firewall_default_zone --add-port=443/tcp
firewall-cmd --permanent --zone=$firewall_default_zone --add-port=22/tcp
firewall-cmd --reload

echo "$(date) INFO: Installing [$puppet-agent] via YUM..." | tee -a  $log_file
yum install -y $puppet_package

echo "$(date) INFO: Downloading & installing Puppet modules from [$module_baseurl]" | tee -a  $log_file
sudo mkdir -p $tmp_puppet_modules
IFS=','
for module in $puppet_modules ; do
  wget $puppet_modules_baseurl/$module -o $tmp_puppet_modules/$module
  sudo puppet module install $tmp_puppet_modules/$module --ignore-dependencies
done

echo "$(date) INFO: Deploying Gitlab via Puppet..." | tee -a  $log_file
cat >$deploy_gitlab_pp <<'EOF'
  class { 'gitlab':
    external_url     => "http://${::hostname}.${domain}",
    #package_ensure   => '7.14.3-ce.1.el6',
    require          => Firewall['080 accept tcp dport 80'],
  }
EOF
export PATH="/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:/opt/puppet/bin:$PATH"
puppet apply $deploy_gitlab_pp -v


