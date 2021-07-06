#!/usr/bin/env bash

RED='\033[01;31m'
RESET='\033[0m'
GREEN='\033[01;32m'

clear
echo -e "$GREEN****************************************************************************************************$RESET"
echo -e "   This Script for Automate install cwp on CentOS , Virtualmin on Ubuntu , ISPConfig on CentOS $RESET"
echo -e "                 You must make sure the hostname is correct before running"
echo -e "                            Github: $GREEN ahmedalazazy"
echo -e "$GREEN***************************************************************************************************$RESET"
echo " "
echo " "
# Check Root Privileges
if [[ $EUID -ne 0 ]];
then
    echo ""
    echo -e "               $RED Hi $USER $RESET"
    echo ""
    echo -e "   $RED Type Your sudo password To using Script $RESET"
    echo ""
    exec sudo /bin/bash "$0" "$@"
fi

echo " "

read -p "Enter c for CWP or v to virtualmin or i for ISPConfig :" PANAL ;

case $PANAL in

  C | c | CWP | centos )
    echo -e "$GREEN******************************************************************************$RESET"
    echo   "$RED \t\t\t\t Hello,$USER this is script to auto install CWP and tools on centOS 7 \n $RESET"
    echo -e "$GREEN******************************************************************************$RESET"
    yum update -y
    yum upgrade -y
    echo 'alias whatismyip="dig @resolver4.opendns.com myip.opendns.com +short"' >> /root/.bashrc
    yum install -y epel-release 
    yum install -y wget ncdu htop vim nano git axel curl bash net-tools openssh-server openssh-clients tree yum-utils ntp ntodate dig
    echo "Type SSHD Port you need to using : "
    read PORT
    echo "Port $PORT" >> /etc/ssh/sshd_config
    echo "Your SSHD Now Using Port $PORT \n"
    echo "MaxAuthTries 10" >> /etc/ssh/sshd_config
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
    systemctl start sshd
    systemctl enable sshd
    ntpdate ntp1.hetzner.de
    echo "driftfile /var/lib/ntp/ntp.drift" > /etc/ntp.conf
    echo "server 0.de.pool.ntp.org iburst" >> /etc/ntp.conf
    echo "server 1.de.pool.ntp.org iburst" >> /etc/ntp.conf  
    echo "servor 2.de.pool.ntp.org iburst" >> /etc/ntp.conf
    echo "server 3.de.pool.ntp.org iburst" >> /etc/ntp.conf
    echo "server  ntp1.hetzner.de  iburst" >> /etc/ntp.conf
    echo "server  ntp2.hetzner.com iburst" >> /etc/ntp.conf
    echo "server  ntp3.hetzner.net iburst" >> /etc/ntp.conf
    echo "leapfile /usr/share/zoneinfo/leap-seconds.list" >> /etc/ntp.conf
    echo "statistics loopstats peerstats clockstats" >> /etc/ntp.conf
    echo "filegen loopstats file loopstats type day enable" >> /etc/ntp.conf
    echo "filegen peerstats file peerstats type day enable" >> /etc/ntp.conf
    echo "filegen clockstats file clockstats type day enable" >> /etc/ntp.conf
    echo "restrict -4 default kod notrap nomodify nopeer noquery limited" >> /etc/ntp.conf
    echo "restrict -6 default kod notrap nomodify nopeer noquery limited" >> /etc/ntp.conf
    echo "restrict 127.0.0.1" >> /etc/ntp.conf
    echo "restrict ::1" >> /etc/ntp.conf
    echo "restrict source notrap nomodify noquery" >> /etc/ntp.conf
    ntpq -p
    cd /usr/local/src
    wget http://centos-webpanel.com/cwp-el7-latest
    chmod +x cwp-el7-latest
    sh cwp-el7-latest -r yes
    ;;

    i | I | ISP | isp | ispconfig | ISPconfig )
    echo -e "$GREEN******************************************************************************$RESET"
    echo   "$RED\t\t\t\t Hello,$USER this is script to auto install ISPConfig and tools on centOS 7  $RESET \n\n\n\n"
    echo -e "$GREEN******************************************************************************$RESET"
    yum update -y
    yum upgrade -y
    echo 'alias whatismyip="dig @resolver4.opendns.com myip.opendns.com +short"' >> /root/.bashrc
    yum install -y epel-release 
    yum install -y wget ncdu htop vim nano git axel curl bash net-tools openssh-server openssh-clients tree yum-utils ntp ntodate dig
    yum install -y groupinstall 'Development Tools'
    yum -y install ntp httpd mod_ssl mariadb-server php php-mysql php-mbstring phpmyadmin
    systemctl start mariadb.service
    systemctl enable mariadb.service
    mysql_secure_installation
    systemctl restart mariadb.service
    yum -y install dovecot dovecot-mysql dovecot-pigeonhole
    touch /etc/dovecot/dovecot-sql.conf
    ln -s /etc/dovecot/dovecot-sql.conf /etc/dovecot-sql.conf
    systemctl restart dovecot.service
    systemctl enable dovecot.service
    yum -y install amavisd-new spamassassin clamav clamd clamav-update unzip bzip2 unrar perl-DBD-mysql
    yum -y install php-ldap php-mysql php-odbc php-pear php php-devel php-gd php-imap php-xml php-xmlrpc php-pecl-apc php-mbstring php-mcrypt php-mssql php-snmp php-soap php-tidy curl curl-devel mod_fcgid php-cli httpd-devel php-fpm perl-libwww-perl ImageMagick libxml2 libxml2-devel python-devel
    yum -y install pure-ftpd
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY*
    yum -y update
    yum -y install pure-ftpd
    yum -y install bind bind-utils
    echo "Type SSHD Port you need to using : "
    read PORT
    echo "Port $PORT" >> /etc/ssh/sshd_config
    echo "Your SSHD Now Using Port $PORT \n"
    echo "MaxAuthTries 10" >> /etc/ssh/sshd_config
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
    systemctl start sshd
    systemctl enable sshd
    ntpdate ntp1.hetzner.de
    echo "driftfile /var/lib/ntp/ntp.drift" > /etc/ntp.conf
    echo "server 0.de.pool.ntp.org iburst" >> /etc/ntp.conf
    echo "server 1.de.pool.ntp.org iburst" >> /etc/ntp.conf  
    echo "servor 2.de.pool.ntp.org iburst" >> /etc/ntp.conf
    echo "server 3.de.pool.ntp.org iburst" >> /etc/ntp.conf
    echo "server  ntp1.hetzner.de  iburst" >> /etc/ntp.conf
    echo "server  ntp2.hetzner.com iburst" >> /etc/ntp.conf
    echo "server  ntp3.hetzner.net iburst" >> /etc/ntp.conf
    echo "leapfile /usr/share/zoneinfo/leap-seconds.list" >> /etc/ntp.conf
    echo "statistics loopstats peerstats clockstats" >> /etc/ntp.conf
    echo "filegen loopstats file loopstats type day enable" >> /etc/ntp.conf
    echo "filegen peerstats file peerstats type day enable" >> /etc/ntp.conf
    echo "filegen clockstats file clockstats type day enable" >> /etc/ntp.conf
    echo "restrict -4 default kod notrap nomodify nopeer noquery limited" >> /etc/ntp.conf
    echo "restrict -6 default kod notrap nomodify nopeer noquery limited" >> /etc/ntp.conf
    echo "restrict 127.0.0.1" >> /etc/ntp.conf
    echo "restrict ::1" >> /etc/ntp.conf
    echo "restrict source notrap nomodify noquery" >> /etc/ntp.conf
    ntpq -p
    cd /opt/
    wget https://ispconfig.org/downloads/ISPConfig-3.2.4.tar.gz
    tar -zxvf ISPConfig-3.2.4.tar.gz
    cd ispconfig3_install/install/
    chmod +x install.php
    php -q install.php
    ;;
  v | V | ubuntu | Ubuntu | virtualmin )
    echo -e "$GREEN**********************************************************************************$RESET"
    echo    "$RED \t\t\t\t Hello,$USER this is script to auto install Virtualmin and tools on Ubuntu  $RESET \n\n\n\n"
    echo -e "$GREEN***********************************************************************************$RESET"
    apt update -y
    apt upgrade -y
    echo 'alias whatismyip="dig @resolver4.opendns.com myip.opendns.com +short"' >> /root/.bashrc
    apt install -y perl wget ncdu htop vim nano git axel curl bash net-tools openssh-server tree ntp ntpdate dig
    echo "Type SSHD Port you need to using : "
    read PORT
    echo "Port $PORT" >> /etc/ssh/sshd_config
    echo "Your SSHD Now Using Port $PORT \n"
    echo "MaxAuthTries 10" >> /etc/ssh/sshd_config
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
    systemctl enable ssh
    systemctl start ssh
    ufw allow ssh
    ufw enable
    dpkg-reconfigure tzdata
    ntpdate ntp1.hetzner.de
    echo "driftfile /var/lib/ntp/ntp.drift" > /etc/ntp.conf
    echo "server 0.de.pool.ntp.org iburst" >> /etc/ntp.conf
    echo "server 1.de.pool.ntp.org iburst" >> /etc/ntp.conf  
    echo "servor 2.de.pool.ntp.org iburst" >> /etc/ntp.conf
    echo "server 3.de.pool.ntp.org iburst" >> /etc/ntp.conf
    echo "server  ntp1.hetzner.de  iburst" >> /etc/ntp.conf
    echo "server  ntp2.hetzner.com iburst" >> /etc/ntp.conf
    echo "server  ntp3.hetzner.net iburst" >> /etc/ntp.conf
    echo "leapfile /usr/share/zoneinfo/leap-seconds.list" >> /etc/ntp.conf
    echo "statistics loopstats peerstats clockstats" >> /etc/ntp.conf
    echo "filegen loopstats file loopstats type day enable" >> /etc/ntp.conf
    echo "filegen peerstats file peerstats type day enable" >> /etc/ntp.conf
    echo "filegen clockstats file clockstats type day enable" >> /etc/ntp.conf
    echo "restrict -4 default kod notrap nomodify nopeer noquery limited" >> /etc/ntp.conf
    echo "restrict -6 default kod notrap nomodify nopeer noquery limited" >> /etc/ntp.conf
    echo "restrict 127.0.0.1" >> /etc/ntp.conf
    echo "restrict ::1" >> /etc/ntp.conf
    echo "restrict source notrap nomodify noquery" >> /etc/ntp.conf
    ntpq -p
    cd /temp/
    wget http://software.virtualmin.com/gpl/scripts/install.sh
    chmod +x install.sh
    sh install.sh
    ;;

  *)
    echo -e "$GREEN******************************************************************************$RESET"
    echo -n                 "$RED unknown what you need to do  $RESET"
    echo -e "$GREEN******************************************************************************$RESET"
    ;;
esac
