#!/bin/bash
# Deploy script for control_repo_setup on Puppetserver
# Creates a new project: control-repo on the remote gitlab server: $git_server, 
## using credentials: $git_user & $git_password
# Pushes a template control-repo repository to the project: control-repo
## - Assumes that /tmp/control-repo-staging exists (used as a template control repo).
# Re-configures all gem sources (inc Puppet server) to point to a local gem repository
## (The default source: https://rubygems.org is removed)
# Configures r10k to point to the newly created control-repo on the gitlab server: $git_server

#Defaults:
log_file='/tmp/configure_control_repo.log'
configure_control_repo_pp='/tmp/configure_control_repo.pp'
tmp_puppet_modules='/tmp/puppet_modules'
control_repo_staging_dir='/tmp/control-repo-staging' #TODO: Expose & parametarize ?

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
maestrodev-ssh_keygen-1.3.1.tar.gz
EOF

echo "$(date) INFO: Downloading & installing Puppet modules from [$puppet_modules_baseurl]" | tee -a  $log_file
puppet resource file $tmp_puppet_modules ensure=directory
IFS=$'\n'
for module in $puppet_modules ; do
  puppet resource file $tmp_puppet_modules/$module ensure=file source=$puppet_modules_baseurl/$module
  puppet module install $tmp_puppet_modules/$module --ignore-dependencies
done




