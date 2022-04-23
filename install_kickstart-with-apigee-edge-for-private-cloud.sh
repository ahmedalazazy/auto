#!/bin/bash
RED='\033[01;31m'
RESET='\033[0m'
GREEN='\033[01;35m'

clear
echo -e "$GREEN****************************************************************************************$RESET"
echo -e "This Script for Automate install Kickstart with Apigee Edge for Private Cloud one VM on redhat or CentOS $RESET"
echo -e "                            Github: $GREEN ahmedalazazy"
echo -e "$GREEN****************************************************************************************$RESET"

# Check Root Privileges
if [[ $EUID -ne 0 ]];
then
    echo ""
    echo -e "                        \t   $RED Hi $USER $RESET"
    echo ""
    echo -e " \t            $RED Type Your sudo password To using Script $RESET"
    echo ""
    exec sudo /bin/bash "$0" "$@"
fi

echo " "
yum update -y
echo "1-System updated  "
sleep 3
yum install git zip unzip wget htop vim nano git curl bash net-tools tree yum-utils dig firewalld gzip -y

echo "2- install needed tools and utilites "
sleep 5
yum install https://rpms.remirepo.net/enterprise/remi-release-7.rpm -y
echo "3- install needed remi repo "
sleep 5
yum repolist
yum -y update

yum-config-manager --disable 'remi-php*'

yum-config-manager --enable remi-php74 

echo "4- enable php7.4 repo   "
yum repolist
yum install php php-bcmath php-common php-cli php-fpm php-gd php-json php-mbstring php-mysql php-mysqlnd php-opcache php-pdo php-process php-xml php-xmlrpc -y

echo "5- install php7.4 &  modules recominded from drupal "
PHPVERS=$(php --version)
if $PHPVERS | grep -q "7.4" ; then
   echo "package php version is 7.4 and already installed"
else
    echo "Please stop script and cheeck the php version "
    exit
fi

sleep 6


php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
php -r "unlink('composer-setup.php');"


echo "6- install php composer done "
sleep 5

echo "1\) CentOS"
echo "2\) Redhat OS"

sleep 3

read -p "Please type The os numbre : " OSNAMEEE;


if [ "$OSNAMEEE" -eq "1" ]; then
cat <<EOF> /etc/yum.repos.d/MariaDB.repo
    # MariaDB 10.6 CentOS repository list - created 2022-04-21 07:42 UTC
    # https://mariadb.org/download/
    [mariadb]
    name = MariaDB
    baseurl = https://mirror1.hs-esslingen.de/pub/Mirrors/mariadb/yum/10.6/centos7-amd64
    gpgkey=https://mirror1.hs-esslingen.de/pub/Mirrors/mariadb/yum/RPM-GPG-KEY-MariaDB
    gpgcheck=1
EOF

    echo "6- add MariaDB 10.6 CentOS repository done "
    sleep 6

    yum repolist
    yum -y update
    sleep 3
    echo "5- install mysql done "
    yum install MariaDB-server MariaDB-client -y
    systemctl start mariadb.service
    systemctl enable mariadb.service
    mariadb-secure-installation


elif [ "$OSNAMEEE" -eq "2" ]; then

cat <<EOF> /etc/yum.repos.d/MariaDB.repo
    # MariaDB 10.6 RedHat repository list - created  UTC
    # https://mariadb.org/download/
    [mariadb]
    name = MariaDB
    baseurl = https://mirror1.hs-esslingen.de/pub/Mirrors/mariadb/yum/10.6/rhel7-amd64
    gpgkey=https://mirror1.hs-esslingen.de/pub/Mirrors/mariadb/yum/RPM-GPG-KEY-MariaDB
    gpgcheck=1
EOF

    echo "6- add MariaDB 10.6 CentOS repository done "
    sleep 6

    yum repolist
    yum -y update
    sleep 3
    echo "5- install mysql done "
    yum install MariaDB-server MariaDB-client -y
    systemctl start mariadb.service
    systemctl enable mariadb.service
    mysql_secure_installation    

else
    echo -e "\t $RED please become a smart ENG $RESET " 

fi

if systemctl status mariadb.service | grep -q "runing" ; then
    echo "7- install DB and run service runing"
else
     echo "7- install DB and run service have an issue please stop script and cheeck"
     exit
fi

read -p "Please type the DB root password you are created on the top: " ROOTPASSWORD;
read -p "Please type the new DB name : " DB;
read -p "Please type the new DB USER : " USER;
read -p "Please type the new DB PASS : " PASS;
mysql -uroot -p'$ROOTPASSWORD' -e "create database $DB";
mysql -uroot -p'$ROOTPASSWORD' -e "create user '$USER'@'localhost' identified by '$PASS'";
mysql -uroot -p'$ROOTPASSWORD' -e "grant all on $DB.* to '$USER' identified by '$PASS'";



echo "8-create DB & add new user done"
sleep 6

echo "please You must add the max_allowed_packet=64M parameter to the [server] section"
echo "file opining now to edite and save"
sleep 6
vim /etc/my.cnf.d/server.cnf 

yum install nginx -y
systemctl start nginx.service
systemctl enable nginx.service

if systemctl status nginx.service | grep -q "runing" ; then
    echo "9- install nginx and run service runing"
else
     echo "9- install nginx and run service have an issue please stop script and cheeck"
     exit
fi

sleep 5

echo "Open /etc/php-fpm.d/www.conf and change the user and group to 'nginx'"
echo "file opining now to edite and save"
sleep 5

vim /etc/php-fpm.d/www.conf

systemctl start php-fpm.service
systemctl enable php-fpm.service

if systemctl status php-fpm.service | grep -q "runing" ; then
    echo "10- install php-fpm and run service runing"
else
     echo "10- install php-fpm and run service have an issue please stop script and cheeck"
    exit
fi

sleep 5

systemctl enable firewalld
systemctl start firewalld
systemctl status firewalld
firewall-cmd --list-services
firewall-cmd --add-service={http,https} --permanent
firewall-cmd --reload
firewall-cmd --list-all

if systemctl status firewalld | grep -q "runing" ; then
    echo "11- install firwall and run service runing"
else
     echo "11- install firwall and run service have an issue please stop script and cheeck"
     exit
fi

sleep 5


curl https://raw.githubusercontent.com/ahmedalazazy/auto/main/nginxconfigration -o /etc/nginx/conf.d/drupal-nginx.conf

echo "12-create NGINX configration file done"


if nginx -t | grep -q "OK" ; then
    echo "13- configration file syntax okay "
    systemctl restart nginx.service
    if systemctl status nginx.service | grep -q "runing" ; then
        echo "14- nginx up and run service runing"

else
     echo "14- nginx service not runing please stop script and cheeck"
     exit
fi

mkdir -p /var/www
adduser devportal
chown -R devportal:devportal /var/www
su - devportal
cd /var/www
echo "export COMPOSER_MEMORY_LIMIT=2G" >> ~devportal/.bash_profile
source ~/.bash_profile

composer config disable-tls false composer create-project apigee/devportal-kickstart-project:9.x-dev portal --no-interaction composer install

cd /var/www/devportal/web/sites/default
cp default.settings.php settings.php
chown -R devportal:nginx settings.php
chmod 660 settings.php

sudo su - root
cd /var/www/devportal/web
chown -R devportal:nginx .
find . -type d -exec chmod u=rwx,g=rx,o= '{}' \;
find . -type f -exec chmod u=rw,g=r,o= '{}' \;

cd /var/www/devportal/web/sites/default && mkdir files

chown -R devportal:nginx .
find . -type d -exec chmod ug=rwx,o= '{}' \;
find . -type f -exec chmod ug=rw,o= '{}' \;

chcon -R -t httpd_sys_content_rw_t /var/www/devportal/web/sites/default


cd /var/www/devportal
mkdir private
cd private

chown -R devportal:nginx .
find . -type d -exec chmod ug=rwx,o= '{}' \;
find . -type f -exec chmod ug=rw,o= '{}' \;
chcon -R -t httpd_sys_content_rw_t /var/www/devportal/private

cat "\$settings['file_private_path'] = '/var/www/devportal/private';" >>/var/www/devportal/web/sites/default/settings.php

cd /temp/
wget -O drush.phar https://github.com/drush-ops/drush-launcher/releases/latest/download/drush.phar
mv drush.phar /usr/local/bin/drush
