#!/bin/bash
# Deploy script for control_repo_setup on Puppetserver

#Defaults:
log_file='/tmp/configure_control_repo.log'
configure_control_repo_pp='/tmp/configure_control_repo.pp'
tmp_puppet_modules='/tmp/puppet_modules'
read -d '' puppet_modules <<'EOF'
puppet-r10k-6.0.0.tar.gz
puppetlabs-stdlib-4.17.0.tar.gz
puppetlabs-ruby-0.6.0.tar.gz
puppetlabs-gcc-0.3.0.tar.gz
abrader-gms-1.0.3.tar.gz
puppet-make-1.1.0.tar.gz
puppetlabs-inifile-1.6.0.tar.gz
puppetlabs-vcsrepo-1.5.0.tar.gz 
puppetlabs-git-0.5.0.tar.gz
gentoo-portage-2.3.0.tar.gz
puppetlabs-concat-2.2.1.tar.gz
EOF

while test $# -gt 0; do
        case "$1" in
                -h|--help)
                        echo "options:"
                        echo "-h, --help                         Show help."
                        echo "-g, --gem_source_url=URL           Gem source url to configure in gemrc sources for installation of new gems."
                        echo "-m, --puppet_modules_baseurl       Base URL for downloading Puppet modules, example: http://repohost.local/puppet_modules"                     
                        echo "-s, --git_server=FQDN              Git server FQDN."
                        echo "-u, --git_user=USER                Git api user."
                        echo "-p, --git_password=PASSWORD        Git api password."
                        echo "-r, --r10k_remote=GIT_REMOTE       Git remote, eg: git@gitlab.local:root/control-repo.git."
                        exit 0
                        ;;
                -g)
                        shift
                        if test $# -gt 0; then
                                gem_source_url=$1
                        else
                                echo "ERROR: --gem_source_url|-g NOT specified."
                                exit 1
                        fi
                        shift
                        ;;
                --gem_source_url*)
                        gem_source_url=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift
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
                -s)
                        shift
                        if test $# -gt 0; then
                                git_server=$1
                        else
                                echo "ERROR: --git_server|-s NOT specified."
                                exit 1
                        fi
                        shift
                        ;;
                --git_server*)
                        git_server=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift
                        ;;      
                -u)
                        shift
                        if test $# -gt 0; then
                                git_user=$1
                        else
                                echo "ERROR: --git_user|-u NOT specified."
                                exit 1
                        fi
                        shift
                        ;;
                --git_user*)
                        git_user=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift
                        ;;      
                -p)
                        shift
                        if test $# -gt 0; then
                                git_password=$1
                        else
                                echo "ERROR: --git_password|-p NOT specified."
                                exit 1
                        fi
                        shift
                        ;;
                --git_password*)
                        git_password=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift
                        ;;  
                -r)
                        shift
                        if test $# -gt 0; then
                                r10k_remote=$1
                        else
                                echo "ERROR: --r10k_remote|-r NOT specified."
                                exit 1
                        fi
                        shift
                        ;;
                --r10k_remote*)
                        r10k_remote=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift
                        ;;      
                *)
                        break
                        ;;
        esac
done

if [[ -z $r10k_remote ]] ; then 
r10k_remote="git@$git_server:$git_user/control-repo.git"
echo "$(date) INFO: --r10k_remote not specified, using git server [$git_server] & git user [$git_user]; $r10k_remote" | tee -a $log_file
fi

echo "$(date) INFO: Setting env path for Puppet & r10k..." | tee -a $log_file
export PATH="/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:/opt/puppet/bin:/usr/bin:$PATH"

echo "$(date) INFO: Getting API token from Git server [$git_server] for Git user [$git_user]..."
puppet resource package jq ensure=installed ; export PATH="$PATH:/usr/bin"
api_token=$(curl http://$git_server/api/v3/session --data "login=$git_user&password=$git_password" | jq -r '.private_token')

echo "$(date) INFO: Creating new project 'control-repo' on Gitlab server [$git_server] for Git user [$git_user]..."
curl -H "Content-Type:application/json" http://$git_server/api/v3/projects?private_token=$api_token -d "{ \"name\": \"control-repo\" }"

echo "$(date) INFO: Generating SSH key for r10k..." | tee -a $log_file
yes y | ssh-keygen -t dsa -C "r10k" -f /root/.ssh/id_dsa_r10k -q -N ''
r10k_public_key=$(cat /root/.ssh/id_dsa_r10k.pub) #=r10k_public_key

echo "$(date) INFO: Downloading & installing Puppet modules from [$puppet_modules_baseurl]" | tee -a  $log_file
puppet resource file $tmp_puppet_modules ensure=directory
IFS=$'\n'
for module in $puppet_modules ; do
  puppet resource file $tmp_puppet_modules/$module ensure=file source=$puppet_modules_baseurl/$module
  puppet module install $tmp_puppet_modules/$module --ignore-dependencies
done

echo "$(date) INFO: Configuring control-repo & R10k via Gitlab API..." | tee -a $log_file
cat >$configure_control_repo_pp <<EOF
  sshkey { '$git_server':
    ensure => present,
    type   => 'ssh-rsa',
    target => '/root/.ssh/known_hosts',
    key    => '$r10k_public_key',
  }
  git_deploy_key { 'gitlab_deploy_key_for_control_repo':
    ensure       => present,
    name         => \$::fqdn,
    path         => '/root/.ssh/id_dsa_r10k.pub',
    token        => '$api_token',
    project_name => 'root/control-repo',
    server_url   => 'http://$git_server',
    provider     => 'gitlab',
  }
  
  # Fix for puppet gem source defaulting to rubygems.org
  exec { 'gem sources --remove https://rubygems.org':
    path    => '/opt/puppetlabs/puppet/bin',
  } 
  exec { 'gem sources --add $gem_source_url':
    path    => '/opt/puppetlabs/puppet/bin',
  } 

  class { '::ruby': }
  class { '::ruby::gemrc': 
    sources => ['$gem_source_url'],
  }
  class { '::ruby::dev': require => Class['::ruby::gemrc'], }

  class {'r10k': 
    remote                 => '$r10k_remote',
    manage_ruby_dependency => 'ignore',
    require                => [
      Class['::ruby'],
      Exec['gem sources --add $gem_source_url'],
    ]
  }
EOF

puppet apply $configure_control_repo_pp -v
r10k deploy environment --puppetfile -v





