#!/bin/bash

#to run this script on VM
#sudo su - root -c 'curl https://raw.githubusercontent.com/ahmedalazazy/auto/main/auto-devportal.sh -o /tmp/auto-devportal.sh && chmod +x /tmp/auto-devportal.sh && bash /tmp/auto-devportal.sh'

RED='\033[01;31m'
RESET='\033[0m'
GREEN='\033[01;35m'

clear
echo -e "$GREEN****************************************************************************************$RESET"
echo -e "This Script for Automate install Drupal DevPortal with Apigee Edge for Private Cloud one VM on Redhat or CentOS $RESET"
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

