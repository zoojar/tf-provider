#!/bin/bash
# Script to set ip ($1) and fqdn ($2) in /etc/hosts - tested on el7
# - David Newton 2017.04.21
ip=$1
fqdn=$2
etc_hosts='/etc/hosts'

if [[ ! -z $ip && ! -z $fqdn ]]; then
  new_line="$ip $fqdn $(echo $fqdn | cut -f1 -d".")"
  echo "Adding [$new_line] to line 1 in [$etc_hosts]..."
  sudo echo -e "$new_line\n$(cat $etc_hosts)" > $etc_hosts
else
  echo "ERROR: Two args expected; IP & FQDN. Example Usage: set_etc_hosts.sh 192.168.0.100 server.local"
  exit 1
fi
