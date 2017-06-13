#!/bin/bash
# Deploy script for control_repo_setup on Puppetserver

#Defaults:
log_file='/tmp/configure_control_repo.log'
configure_control_repo_pp='/tmp/configure_control_repo.pp'

while test $# -gt 0; do
        case "$1" in
                -h|--help)
                        echo "options:"
                        echo "-h, --help                         Show help."
                        echo "-s, --git_server=FQDN              Git server FQDN."
                        echo "-u, --git_user=USER                Git api user."
                        echo "-p, --git_password=PASSWORD        Git api password."
                        echo "-r, --r10k_remote=GIT_REMOTE       Git remote, eg: git@gitlab.local:root/control-repo.git."
                        exit 0
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

echo "$(date) INFO: Configuring control-repo & R10k via Gitlab API..." | tee -a $log_file
puppet module install puppet-r10k --version 4.2.0
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
    project_name => 'puppet/control',
    server_url   => '$git_server',
    provider     => 'gitlab',
  }
  class {'r10k': remote => '$r10k_remote',}
EOF

puppet apply $configure_control_repo_pp -v
r10k deploy environment --puppetfile -v





