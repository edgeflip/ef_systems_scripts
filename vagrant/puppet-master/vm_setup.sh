#!/usr/bin/env bash
sudo apt-get update
cp /home/vagrant/.ssh/authorized_keys /home/vagrant/.ssh/authorized_keys.VAGRANT_ORIG
cp /home/vagrant/ssh_keys/* /home/vagrant/.ssh/
sudo chown -R vagrant:vagrant /home/vagrant/.ssh

sed -i "s/127.0.0.1\tlocalhost/127.0.0.1\tlocalhost puppetmaster/" /etc/hosts
echo "puppetmaster" > /etc/hostname
sudo hostname puppetmaster

sudo apt-get install -y puppetmaster tmux vim git git-core
echo "eflip-*" >> /etc/puppet/autosign.conf
echo "edgeflip-*" >> /etc/puppet/autosign.conf
echo "10.0.0.0" >> /etc/puppet/autosign.conf
git clone git@github.com:edgeflip/ef_system_configurations.git
cat > /home/vagrant/refresh.sh <<'endmsg'
sudo rm -rf /etc/puppet/manifests
sudo rm -rf /etc/puppet/modules
sudo cp -r /home/vagrant/ef_system_configurations/manifests /etc/puppet/manifests
sudo cp -r /home/vagrant/ef_system_configurations/modules /etc/puppet/modules
sudo service puppetmaster restart
endmsg
chmod +x /home/vagrant/refresh.sh
/home/vagrant/refresh.sh
sudo service puppetmaster restart
