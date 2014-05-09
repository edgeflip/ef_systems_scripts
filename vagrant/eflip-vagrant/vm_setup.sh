#!/usr/bin/env bash

apt-get update
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
sudo apt-get install -y git python-pip python-dev tmux mysql-server
sudo pip install distribute --upgrade
sudo pip install Fabric
cp /home/vagrant/.ssh/authorized_keys /home/vagrant/.ssh/authorized_keys.VAGRANT_ORIG
cp /home/vagrant/ssh_keys/* /home/vagrant/.ssh/
sudo chown -R vagrant:vagrant /home/vagrant/.ssh
