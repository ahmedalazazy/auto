#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
RESET='\033[0m'

clear
echo -e "$GREEN****************************************************************************************$RESET"
echo -e "$GREEN============== This Script for Automate install Apigee Edge ============================$RESET"
echo -e "                            Github: $GREEN ahmedalazazy"
echo -e "$GREEN****************************************************************************************$RESET"
echo " "
echo " "

# Functions

CHOSE_APIGEE_VERSION() {
  echo "Choose Apigee Edge version: "
  echo "1. 4.52.00"
  echo "2. 4.51.00"
  read -p "Choose the APigee Version do you need: " APIGEE_VERSION
  case $APIGEE_VERSION in
    1)
      APIGEE_VERSION="4.52.00"
      ;;
    2)
      APIGEE_VERSION="4.51.00"
      ;;
    *)
      echo "Invalid option"
      exit 1
      ;;
  esac
  echo "Apigee Version is : ${APIGEE_VERSION}"
}

check_netcat() {
    if command -v nc &> /dev/null; then
        echo "Netcat is installed. Trying to connect to software.apigee.com on port 443..."
        if nc -v -z -w 5 software.apigee.com 443 2>&1; then
            echo "Connection succeeded!"
            return 0
        else
            echo "Connection failed."
            return 1
        fi
    else
        echo "Netcat is not installed. Please install netcat and try again."
        return 1
    fi
}

firewall_requirements() {
    echo "Installing firewall requirements"
    # Add your installation logic here
    # Disable SELinux
    echo "Disabling SELinux..."
    sudo setenforce 0
    sudo sed -i.bak 's/SELINUX=.*/SELINUX=permissive/' /etc/sysconfig/selinux
    # Disable Firewall
    systemctl stop firewalld
    systemctl disable firewalld
}



install_requirements() {

  echo "Installing requirements"
  # Add your installation logic here
  #update the system
  echo "Updating the system before start"
  sudo sed -i.bak 's/clean_requirements_on_remove=.*/clean_requirements_on_remove=False/' /etc/yum.conf
  sudo dnf update -y

  # Disable IPv6
  echo "Disabling IPv6..."
  sudo sed -i.bak '/::/s/^/#/' /etc/hosts
  sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
  sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1

  # Disable Firewall requirements
  firewall_requirements

  # Update NSS
  echo "Updating NSS..."
  sudo yum -y update nss
  sudo yum info nss
  
  # Enable EPEL Repo
  # echo "Enabling EPEL Repo..."
  
  
  # Entropy Pool
  echo "Configuring Entropy Pool..."
  sudo yum -y install rng-tools
  sudo sed -i.bak 's/ExecStart=/sbin/rngd -f/ExecStart=/sbin/rngd -f -r /dev/urandom/' /usr/lib/systemd/system/rngd.service
  sudo systemctl daemon-reload
  sudo systemctl start rngd
  sudo systemctl status rngd
  # cat /dev/random #this line was the issue
  
  # Log in as root
  echo "Logging in as root..."
  sudo whoami
    
  # Disable Postgres and NGINX
  echo "Disabling Postgres and NGINX..."
  sudo dnf module disable -y postgresql
  sudo dnf module disable -y nginx
  
  # Install Python 2 and create a symlink
  echo "Installing Python 2..."
  sudo dnf install -y python2
  sudo ln -s /usr/bin/python2 /usr/bin/python

  echo "Script completed."
  # Add apigee-user and group 'apigee'
  sudo groupadd -r  apigee && useradd -r -g apigee -d /opt/apigee -s /sbin/nologin -c 'Apigee platform user' apigee
 
  # Create directories
  sudo mkdir -p /u01/apigee
  # Create symbolic link
  sudo ln -Ts /u01/apigee /opt/apigee
  
  # Set ownership
  sudo chown -h apigee:apigee /u01/apigee /opt/apigee
  # Change the working directory
  cd /opt/apigee
  echo "Disk setup and user/group creation completed successfully."
  
  #crb
  sudo /usr/bin/crb enable
  # Install epel-release
  sudo dnf install -y epel-release 
  # Install admin tools
  dnf install -y wget  vim nano curl bash  net-tools tree yum-utils gzip git zip unzip htop telnet nmap-ncat
  echo "please paste license file "
  sleep 5
  vim /tmp/license.txt
  echo " Please paste the installation configration file after change the needed var "
  sleep 5
  echo "if you not have configration file link folow the below link"
  sleep 5
  echo "https://docs.apigee.com/private-cloud/v4.52.00/install-edge-components-node#installedgecomponents-allinoneinstallation"
  sleep 5
  vim /tmp/configFile
  echo "Apigee requirements installed successfully."
  CHOSE_APIGEE_VERSION
  read -p "Please type the apigeeuser proved py apige subscription : " UUUSSSESR;
  read -p "Please type the apigeepassword proved py apige subscription : " PASSSWORDDD;
  echo "Apigee Version is : ${APIGEE_VERSION}"
  sleep 5
  echo "Apigee PASS is : ${PASSSWORDDD}"
  sleep 5
  echo "Apigee USER is : ${UUUSSSESR}" 
  sleep 5
  # Call the function to check netcat and apigee repo connection
  check_netcat
  # Check the return status and run the sudo curl command if successful
  if [ $? -eq 0 ]; then
      sudo curl -s https://software.apigee.com/bootstrap_${APIGEE_VERSION}.sh -o /tmp/bootstrap_${APIGEE_VERSION}.sh
  fi
  sudo bash /tmp/bootstrap_${APIGEE_VERSION}.sh apigeeuser="${UUUSSSESR}" apigeepassword="${PASSSWORDDD}"
  sudo dnf -v repolist 'apigee*'
  sudo dnf update -y
}

install_apigee() {
  echo "Installing Apigee Edge : $TOPOLOGY"
  echo "1- All-in-One with Single Apigee Edge Node"
  echo "2- 2-node"
  echo "3- 5-node"
  echo "4- 9-node"
  echo "5- 13-node"
  echo "6- 12-node"

  read -p "Choose the APigee installation TOPOLOGY do you need: " TOPOLOGY;

  case $TOPOLOGY in
    1)
      echo "Installing All-in-One topology..."
      # Add your installation logic for the All-in-One topology
        CHOSE_APIGEE_VERSION
        /opt/apigee/apigee-service/bin/apigee-service apigee-setup install
        /opt/apigee/apigee-service/bin/apigee-service apigee-provision install
        /opt/apigee/apigee-setup/bin/setup.sh -p aio -f /tmp/configFile -t
        sleep 6
        /opt/apigee/apigee-setup/bin/setup.sh -p aio -f /tmp/configFile
        echo "Installing All-in-One topology..."
      ;;
    2)
      echo "Installing 2-node standalone topology..."
      # Add your installation logic for the 2-node standalone topology
      CHOSE_APIGEE_VERSION
      echo "Installing for the 2-node standalone topology..."
      echo "Choose an option:"
      echo "1. Install Standalone Gateway on node 1"
      echo "2. Install Analytics on node 2"
      echo "3. Restart the Classic UI component on node 1"
      read -p "Enter your choice (1-3): " choice

      case $choice in
          1)
              /opt/apigee/apigee-setup/bin/setup.sh -p sa -f /tmp/configFile
              ;;
          2)
              /opt/apigee/apigee-setup/bin/setup.sh -p sax -f /tmp/configFile
              ;;
          3)
              /opt/apigee/apigee-service/bin/apigee-service edge-ui restart
              ;;
          *)
              echo "Invalid choice. Exiting."
              ;;
      esac
      ;;

    3)
      echo "Installing 5-node topology..."
      # Add your installation logic for the 5-node topology
      CHOSE_APIGEE_VERSION
      echo "Installing 5-node clustered topology..."
      echo "Choose an option:"
      echo "1. Install Datastore Cluster on nodes 1, 2, and 3"
      echo "2. Install Management Server on node 1"
      echo "3. Install Router and Message Processor on nodes 2 and 3"
      echo "4. Install Analytics on nodes 4 and 5"
      echo "5. Restart the Classic UI component on node 1"
      read -p "Enter your choice (1-5): " choice
      case $choice in
          1)
              /opt/apigee/apigee-setup/bin/setup.sh -p ds -f /tmp/configFile
              ;;
          2)
              /opt/apigee/apigee-setup/bin/setup.sh -p ms -f /tmp/configFile
              ;;
          3)
              /opt/apigee/apigee-setup/bin/setup.sh -p rmp -f /tmp/configFile
              ;;
          4)
              /opt/apigee/apigee-setup/bin/setup.sh -p sax -f /tmp/configFile
              ;;
          5)
              /opt/apigee/apigee-service/bin/apigee-service edge-ui restart
              ;;
          *)
              echo "Invalid choice. Exiting."
              ;;
      esac
      ;;

    4)
      echo "Installing 9-node clustered topology..."
      # Add your installation logic for the 9-node clustered topology
      CHOSE_APIGEE_VERSION
      echo "Choose an option:"
      echo "1. Install Datastore Cluster Node on nodes 1, 2, and 3"
      echo "2. Install Apigee Management Server on node 1"
      echo "3. Install Router and Message Processor on nodes 4 and 5"
      echo "4. Install Apigee Analytics Qpid Server on nodes 6 and 7"
      echo "5. Install Apigee Analytics Postgres Server on nodes 8 and 9"
      echo "6. Restart the Classic UI component on node 1"
      read -p "Enter your choice (1-6): " choice
      case $choice in
          1)
              /opt/apigee/apigee-setup/bin/setup.sh -p ds -f /tmp/configFile
              ;;
          2)
              /opt/apigee/apigee-setup/bin/setup.sh -p ms -f /tmp/configFile
              ;;
          3)
              /opt/apigee/apigee-setup/bin/setup.sh -p rmp -f /tmp/configFile
              ;;
          4)
              /opt/apigee/apigee-setup/bin/setup.sh -p qs -f /tmp/configFile
              ;;
          5)
              /opt/apigee/apigee-setup/bin/setup.sh -p ps -f /tmp/configFile
              ;;
          6)
              /opt/apigee/apigee-service/bin/apigee-service edge-ui restart
              ;;
          *)
              echo "Invalid choice. Exiting."
              ;;
      esac
      ;;
    5)
      echo "Installing 13-node clustered topology..."
      # Add your installation logic for the 13-node clustered topology
      CHOSE_APIGEE_VERSION
      ;;
    6)
      echo "Installing 12-node clustered topology..."
      # Add your installation logic for the 12-node clustered topology
      CHOSE_APIGEE_VERSION
      ;;
    *)
      echo "Unsupported topology: $TOPOLOGY"
      # Handle unsupported topology
      ;;
  esac
}

update_apigee() {
  echo "Updating Apigee Edge"
  # Add your update logic here
}

create_apigee_organization() {
    echo "Creating Apigee Organization"
    # Add your organization creation logic here
    sleep 9
    echo "paste org configration file to onpord the org "
    echo "if you not have configration file link folow the below link"
    sleep 5
    echo "https://docs.apigee.com/private-cloud/v4.52.00/onboard-organization"
    sleep 5
    /opt/apigee/apigee-service/bin/apigee-service edge-ui restart
    vim /tmp/onfigcration_file
    sleep 5
    /opt/apigee/apigee-service/bin/apigee-service apigee-provision setup-org -f /tmp/onfigcration_file
    /opt/apigee/apigee-service/bin/apigee-service apigee-provision add-env
    /opt/apigee/apigee-service/bin/apigee-all enable_autostart
    /opt/apigee/apigee-service/bin/apigee-service edge-ui restart

}

create_apigee_environment() {
  echo "Creating Apigee Environment"
  # Add your environment creation logic here
}

enable_apigee_monetization() {
  echo "Enabling Apigee Monetization"
  # Add your monetization logic here
}

set_password() {
  echo "Setting password"
  # Add your password logic here
}

create_apigee_user() {
  echo "Creating Apigee User"
  # Add your user creation logic here
}

uninstall_apigee(){
  echo "Uninstalling Apigee Edge"
  echo "1- Uninstalling Apigee Edge all components"

  echo "2- Uninstalling Apigee Edge  apigee-cassandra (Cassandra)"
  echo "3- Uninstalling Apigee Edge apigee-openldap (OpenLDAP)"
  echo "4- Uninstalling Apigee Edge apigee-postgresql (PostgreSQL database)"
  echo "5- Uninstalling Apigee Edge apigee-qpidd (Qpidd)"
  echo "6- Uninstalling Apigee Edge apigee-sso (Edge SSO)"
  echo "7- Uninstalling Apigee Edge apigee-zookeeper (ZooKeeper)"
  echo "8- Uninstalling Apigee Edge edge-management-server (Management Server)"
  echo "9- Uninstalling Apigee Edge edge-management-ui (new Edge UI)"
  echo "10- Uninstalling Apigee Edge edge-message-processor (Message Processor)"
  echo "11- Uninstalling Apigee Edge edge-postgres-server (Postgres Server)"
  echo "12- Uninstalling Apigee Edge edge-qpid-server (Qpid Server)"
  echo "13- Uninstalling Apigee Edge edge-router (Edge Router)"
  echo "14- Uninstalling Apigee Edge edge-ui (Classic UI)"
  read -p "chose your option:" APigee_UNINSTALL_OPTION;
  sleep 9
  case $APigee_UNINSTALL_OPTION in
    1)
      echo "Uninstalling Apigee Edge all components"
      /opt/apigee/apigee-service/bin/apigee-all stop
      sudo yum clean all
      /opt/apigee/apigee-service/bin/apigee-service apigee-service uninstall
      ;;

    2)
      echo "Uninstalling Apigee Edge  apigee-cassandra (Cassandra)"
      /opt/apigee/apigee-service/bin/apigee-service apigee-cassandra uninstall
      ;;
    3)
      echo "Uninstalling Apigee Edge apigee-openldap (OpenLDAP)"
      /opt/apigee/apigee-service/bin/apigee-service apigee-openldap uninstall
      ;;
    4)
      echo "Uninstalling Apigee Edge apigee-postgresql (PostgreSQL database)"
      /opt/apigee/apigee-service/bin/apigee-service apigee-postgresql uninstall
      ;;
    5)
      echo "Uninstalling Apigee Edge apigee-qpidd (Qpidd)"
      /opt/apigee/apigee-service/bin/apigee-service apigee-qpidd uninstall
      ;;
    6)
      echo "Uninstalling Apigee Edge apigee-sso (Edge SSO)"
      /opt/apigee/apigee-service/bin/apigee-service apigee-sso uninstall
      ;;
    7)
      echo "Uninstalling Apigee Edge apigee-zookeeper (ZooKeeper)"
      /opt/apigee/apigee-service/bin/apigee-service apigee-zookeeper uninstall
      ;;
    8)
      echo "Uninstalling Apigee Edge edge-management-server (Management Server)"
      /opt/apigee/apigee-service/bin/apigee-service edge-management-server uninstall
      ;;
    9)
      echo "Uninstalling Apigee Edge edge-management-ui (new Edge UI)"
      /opt/apigee/apigee-service/bin/apigee-service edge-management-ui uninstall
      ;;
    10)
      echo "Uninstalling Apigee Edge edge-message-processor (Message Processor)"
      /opt/apigee/apigee-service/bin/apigee-service edge-message-processor uninstall
      ;;
    11)
      echo "Uninstalling Apigee Edge edge-postgres-server (Postgres Server)"
      /opt/apigee/apigee-service/bin/apigee-service edge-postgres-server uninstall
      ;;
    12)
      echo "Uninstalling Apigee Edge dge-qpid-server (Qpid Server)"
      /opt/apigee/apigee-service/bin/apigee-service edge-qpid-server uninstall
      ;;
    13)
      echo "Uninstalling Apigee Edge edge-router (Edge Router)"
      /opt/apigee/apigee-service/bin/apigee-service edge-router uninstall
      ;;
    14)
      echo "Uninstalling Apigee Edge edge-ui (Classic UI)"
      /opt/apigee/apigee-service/bin/apigee-service edge-ui uninstall
      ;;

    *)
      echo "Invalid option"
      exit 1
      ;;
  esac

  # Add your uninstall logic here

}

# Main menu
echo ""
echo "0. Install Requirements"
echo "1. Install Apigee Edge"
echo "2. Firewall Requirements"
echo "3. Update Apigee Edge"
echo "4. Create Apigee Organization"
echo "5. Create Apigee Environment"
echo "6. Enable Apigee Monetization"
echo "7. Set Password"
echo "8. Create Apigee User"
echo "9. uninstall apigee"
echo "10. Exit"

read -p "Enter your choice: " choice

case "$choice" in
  0)
    install_requirements
    ;;
  1)
    install_apigee
    ;;
  2)
    firewall_requirements
    ;;
  3)
    update_apigee
    ;;
  4)
    create_apigee_organization
    ;;
  5)
    create_apigee_environment
    ;;
  6)
    enable_apigee_monetization
    ;;
  7)
    set_password
    ;;
  8)
    create_apigee_user
    ;;
  9)
    uninstall_apigee
    ;;

  10)
    echo "Exiting script"
    exit 0
    ;;

  *)
    echo "Invalid choice. Please enter a valid option."
    ;;
esac
