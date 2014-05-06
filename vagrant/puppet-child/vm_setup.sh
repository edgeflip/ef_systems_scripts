#!/usr/bin/env bash
PUPPETMASTER_IP=$1
CERTNAME=$2

if [ -z "${PUPPETMASTER_IP}" ]; then
    echo "This setup requires the PUPPETMASTER_IP env var to be set. Failing".
    exit 1
fi
if [ -z "${CERTNAME}" ]; then
    echo "This setup requires that CERTNAME be set and equal to the certname you wish to use in your puppet config"
    exit 1
fi

echo $PUPPETMASTER_IP
echo $CERTNAME

# Update apt
sudo apt-get update
sudo apt-get install -y vim tmux

# Setup our user
cp /home/vagrant/.ssh/authorized_keys /home/vagrant/.ssh/authorized_keys.VAGRANT_ORIG
cp /home/vagrant/ssh_keys/* /home/vagrant/.ssh/

# Get hostname and /etc/hosts straightened out
cat /etc/hosts
sed -i "s/127.0.0.1\tlocalhost/127.0.0.1\tlocalhost puppet-child/" /etc/hosts
echo "${PUPPETMASTER_IP}    puppetmaster" >> /etc/hosts
echo "puppet-child" > /etc/hostname
sudo hostname puppet-child

# S3 CFG file
cat > /root/.s3cfg-creds <<'endmsg'
access_key = AKIAIQJVB6QVSC6XMROA
secret_key = 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
endmsg

# Get an `ubuntu` user going to make puppet happier
sudo useradd -Gsudo,admin -d/home/ubuntu -k/etc/skel -m ubuntu
sudo chown -R vagrant:vagrant /home/vagrant/.ssh
sudo mkdir /home/ubuntu/.ssh
sudo chown -R ubuntu:ubuntu /home/ubuntu

# Get puppet installed
wget http://apt.puppetlabs.com/pool/precise/main/p/puppet/puppet-common_2.7.22-1puppetlabs1_all.deb
wget http://apt.puppetlabs.com/pool/precise/main/p/puppet/puppet_2.7.22-1puppetlabs1_all.deb
sudo apt-get install -y augeas-lenses facter libaugeas-ruby1.8 libaugeas0 libruby libshadow-ruby1.8 ruby1.8
sudo dpkg --force-confold -i puppet-common_2.7.22-1puppetlabs1_all.deb
sudo dpkg --force-confold -i puppet_2.7.22-1puppetlabs1_all.deb
cat >> /etc/puppet/puppet.conf <<endmsg
[agent]
certname = ${CERTNAME}
runinterval = 300
factpath = $vardir/lib/puppet/facter
server = puppetmaster
node_name = cert
endmsg
sudo sed -i "s/START=no/START=yes/" /etc/default/puppet
sudo service puppet restart

echo "Things you will want to do next: "
echo "Login to your puppetmaster and run this: sudo puppet cert sign --all"
