#!/bin/bash

RED='\033[01;31m'
RESET='\033[0m'
GREEN='\033[01;35m'

clear
echo -e "$GREEN****************************************************************************************$RESET"
echo -e "   This Script for Automate install APGI All in one VM on redhat or CentOS $RESET"
echo -e "                            Github: $GREEN ahmedalazazy"
echo -e "$GREEN****************************************************************************************$RESET"
echo " "
echo " "

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

read -p "Please type the apigeeuser proved py apige subscription : " UUUSSSESR;
read -p "Please type the apigeepassword proved py apige subscription : " PASSSWORDDD;
sudo setenforce 0
echo "1-disable selinux "
sleep 5

sudo yum update -y
sleep 5
echo "5-System updated  "
sleep 5
yum install -y wget htop vim nano curl bash yum-utils yum-plugin-priorities net-tools tree yum-utils gzip 

echo "3- install needed tools and utilites "
sleep 5
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm 
sleep 5
sudo rpm -ivh epel-release-latest-7.noarch.rpm

echo "4- add epel  note : on redhat 7 linux GCP image alredy epel install so no issues if you see error"
sleep 5


status="$(rpm -qa | grep libdb4)"
if [ ! $? = 0 ] || [ ! "$status" = libdb4 ]; then

    echo "libdb4 not installd "
else
    echo "libdb4 uninstall it"
    sudo yum remove libdb4
fi


echo "5- If you see that the libdb4 RPM version is later than version 4.8, uninstall it. "
sleep 3


if [  -n "$(uname -a | grep centos)" ]; then
    adduser -m -s /sbin/nologin -c "Apigee platform user" apigee 
else
    groupadd -r apigee > useradd -r -g apigee -d /opt/apigee -s /sbin/nologin -c "Apigee platform user" apigee
fi  

sleep 5
echo "6- Create the apigee user and group: "
sleep 5

curl https://software.apigee.com/bootstrap_4.18.05.sh -o /tmp/bootstrap_4.18.05.sh
echo "7- download bootstrap instalittion file  "
sleep 5
echo "if asking you to install openjdk type 1 or accept"
sleep 5
sudo bash /tmp/bootstrap_4.18.05.sh apigeeuser="$UUUSSSESR" apigeepassword="$PASSSWORDDD"

echo "8- exec bootstrap installationon file to add apigee repo"
sleep 5
sudo yum -v repolist 'apigee*'
sleep 5
sudo yum update -y
echo "9- validate apigee repositores installd"
sleep 9
/opt/apigee/apigee-service/bin/apigee-service apigee-setup install
echo "10- run install apigee-setip"
sleep 9
/opt/apigee/apigee-service/bin/apigee-service apigee-provision install
sleep 9

echo "please paste license file "
sleep 5
vim /tmp/license.txt
echo " Please paste the installation all in one configration file after change the needed var "
sleep 5
echo "if you not have configration file link folow the below link"
sleep 5
echo "https://docs.apigee.com/private-cloud/v4.19.06/install-edge-components-node#installedgecomponents-allinoneinstallation"
sleep 5
vim /tmp/configFile

echo "please validate no isseis on test /tmp/configFile seting as below"
sleep 5
/opt/apigee/apigee-setup/bin/setup.sh -p aio -f /tmp/configFile -t
sleep 6
/opt/apigee/apigee-setup/bin/setup.sh -p aio -f /tmp/configFile
sleep 9
echo "paste org configration file to onpord the org "
echo "if you not have configration file link folow the below link"
sleep 5
echo "https://docs.apigee.com/private-cloud/v4.51.00/onboard-organization"
sleep 5

vim /tmp/configFile2
sleep 5
/opt/apigee/apigee-service/bin/apigee-service apigee-provision create-org -f /tmp/configFile2
