#!/bin/sh
# Force local site repo
yumrepo_baseurl=$1

rm -f /etc/yum.repos.d/*
cat <<EOL > /etc/yum.repos.d/local.site.repo
[local.site.repo]
name=LocalSiteRepo
baseurl=$yumrepo_baseurl
enabled=1
gpgcheck=0
EOL