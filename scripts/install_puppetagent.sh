#!/bin/bash
# Script to install, configure & autosign Puppet Agent via yum - tested on el7.
# - David Newton 2017.04.21

puppet_package='puppet-agent'
#set -e # Abort on error

while test $# -gt 0; do
        case "$1" in
                -h|--help)
                        echo "options:"
                        echo "-h, --help                         Show help."
                        echo "-f, --puppetserver_fqdn=FQDN             FQDN of puppet master (used for setting /etc/hosts)."
                        echo "-p, --psk=Pre-shared key           Autosigning pre-shared key to embed in the certificate request."
                        echo "-r, --role=Role                    Role (value of pp_role) to embed in the certificate request."
                        exit 0
                        ;;
                -f)
                        shift
                        if test $# -gt 0; then
                                puppetserver_fqdn=$1
                        else
                                echo "ERROR: No FQDN for puppet master specified."
                                exit 1
                        fi
                        shift
                        ;;
                --puppetserver_fqdn*)
                        puppetserver_fqdn=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift
                        ;;
                -p)
                        shift
                        if test $# -gt 0; then
                                psk=$1
                        else
                                echo "ERROR: No pre-shared key specified."
                                exit 1
                        fi
                        shift
                        ;;
                --psk*)
                        psk=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift
                        ;;
                -r)
                        shift
                        if test $# -gt 0; then
                                role=$1
                        else
                                echo "ERROR: No role specified."
                                exit 1
                        fi
                        shift
                        ;;
                --role*)
                        role=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift
                        ;;
                *)
                        break
                        ;;
        esac
done

if [[ ! -z $psk || ! -z $role ]]; then
  echo "$(date) INFO: Setting up custom csr attributes for autosigning..."
  mkdir -p /etc/puppetlabs/puppet
  printf "custom_attributes:\n  1.2.840.113549.1.9.7: $psk\nextension_requests:\n  pp_role: $role\n" >  /etc/puppetlabs/puppet/csr_attributes.yaml 
fi

sudo yum install -y $puppet_package 

export PATH="/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:/opt/puppet/bin:$PATH"

if [[ ! -z $puppetserver_fqdn ]]; then
  echo "$(date) INFO: Configuring puppet with master server $puppetserver_fqdn..."
  puppet config set server $puppetserver_fqdn
fi

echo "$(date) INFO: Running puppet agent..."
puppet agent -t

echo "$(date) INFO: Done."


