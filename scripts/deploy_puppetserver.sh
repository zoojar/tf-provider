#!/bin/bash
# Deploy script for Puppetserver, installs, configures & starts Puppetserver

#Defaults:
log_file='/tmp/deploy_puppetserver.log'
psk_default='changeme'
autosign_sh='/etc/puppetlabs/puppet/autosign.sh'

while test $# -gt 0; do
        case "$1" in
                -h|--help)
                        echo "options:"
                        echo "-h, --help                         Show help."
                        echo "-p, --psk=PSK                      IP address of puppet master (used for setting /etc/hosts)."
                        exit 0
                        ;;
                -p)
                        shift
                        if test $# -gt 0; then
                                psk=$1
                        else
                                echo "INFO: No PSK specified - using default: $psk_default"
                                psk=$psk_default
                        fi
                        shift
                        ;;
                --psk*)
                        psk=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift
                        ;;
                *)
                        break
                        ;;
        esac
done


firewall_default_zone=`sudo firewall-cmd --get-default-zone`
echo "$(date) INFO: Configuring firewall: Opening ports 8140, 443, 61613 & 8142 for the default zone: ${firewall_default_zone}..." | tee -a  $log_file
firewall-cmd --permanent --zone=$firewall_default_zone --add-port=8140/tcp
firewall-cmd --permanent --zone=$firewall_default_zone --add-port=443/tcp
firewall-cmd --permanent --zone=$firewall_default_zone --add-port=61613/tcp
firewall-cmd --permanent --zone=$firewall_default_zone --add-port=8142/tcp
firewall-cmd --permanent --zone=$firewall_default_zone --add-port=4433/tcp
firewall-cmd --reload

echo "$(date) INFO: Installing puppetserver..." | tee -a $log_file
yum -y install puppetserver

echo "$(date) INFO: Setting env path for Puppet & r10k..." | tee -a $log_file
export PATH="/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:/opt/puppet/bin:/usr/bin:$PATH"

if [[ ! -z $psk ]]; then
echo "$(date) INFO: Configuring autosigning..." | tee -a $log_file
echo $psk >/etc/puppetlabs/puppet/global-psk
cat >$autosign_sh <<'EOF'
#!/bin/bash
csr=$(< /dev/stdin)
certname=$1
textformat=$(echo "$csr" | openssl req -noout -text)
global_psk=$(cat /etc/puppetlabs/puppet/global-psk)
if [ "$(echo $textformat | grep -Po $global_psk)" = "$global_psk" ]; then
  echo -e "CSR Stdin contains: $csr \n\nInfo: Autosigning $certname with global-psk $global_psk..." >> /tmp/autosign.log
  exit 0
else
  echo -e "CSR Stdin contains: $csr \n\nWarn: Not Autosigning $certname with global-psk $global_psk - no match." >> /tmp/autosign.log
  exit 1
fi
EOF
chmod 500 $autosign_sh ; sudo chown puppet $autosign_sh
puppet config set autosign $autosign_sh --section master
fi

echo "$(date) INFO: Enabling & starting puppetserver..." | tee -a $log_file
puppet apply -e "service { 'puppetserver': enable => true, }"
service puppetserver start
