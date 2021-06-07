#!/usr/bin/env bash
echo -n "THis Script for automatic install cwp on CentOS and install virtualmin on Ubuntu";
echo -n "You must make sure the hostname is correct before running";
read -p "Enter C for cwp or v to virtualmin" PANAL ;

case $PANAL in

  C | c | CWP | centos )
    echo "Hello,$USER this is script to auto install CWP and tools on centOS 7 "
    yum update -y
    yum upgrade -y
    alias whatismyip="dig @resolver4.opendns.com myip.opendns.com +short"
    yum install -y epel-release 
    yum install -y wget ncdu htop vim nano git axel curl bash net-tools openssh-server openssh-clients tree yum-utils
    systemctl start sshd
    systemctl enable sshd
    cd /usr/local/src
    wget http://centos-webpanel.com/cwp-el7-latest
    chmod +x cwp-el7-latest
    sh cwp-el7-latest -r yes --softaculous yes
    ;;

  v | V | ubuntu | Ubuntu | virtualmin )
    apt update -y
    apt upgrade -y
    alias whatismyip="dig @resolver4.opendns.com myip.opendns.com +short"
    apt install -y perl wget ncdu htop vim nano git axel curl bash net-tools openssh-server tree
    systemctl enable ssh
    systemctl start ssh
    ufw allow ssh
    ufw enable
    cd /temp/
    wget http://software.virtualmin.com/gpl/scripts/install.sh
    chmod +x install.sh
    sh install.sh
    ;;

  *)
    echo -n "unknown what you need to do "
    ;;
esac

