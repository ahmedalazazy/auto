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

function clone_repo() {
    read -p "Username: " USERNAME
    read -s -p "Password or Access Token: " PASSWORD
    echo ""
    read -p "Repository URL: " REPO_URL
    read -p "Branch or Tag Name (default: main/master): " BRANCH_OR_TAG
    BRANCH_OR_TAG=${BRANCH_OR_TAG:-main}
    DESTINATION_DIR="/source"
    if [ ! -d $DESTINATION_DIR ]
	then
	     mkdir $DESTINATION_DIR
	else
	     echo "Directory exists"
	fi

    # Clone the repository silently with authentication
    git clone --quiet --depth 1 https://${USERNAME}:${PASSWORD}@${REPO_URL} --branch ${BRANCH_OR_TAG} ${DESTINATION_DIR}

    # Verify if the clone was successful
    if [ $? -eq 0 ]; then
        echo "Cloned successfully!"
    else
        echo "Clone failed. Please check your credentials or repository URL."
    fi
    
}



function update_devportal {
    read -p "Enter the source directory (e.g., /source/portal-code): " source_dir
    read -p "Enter the devportal directory (e.g., /var/www/devportal): " dir

    sudo rm -rf "$dir/composer.json"
    echo "rm composer"
    sudo rm -rf "$dir/patches/"
    echo "rm patches"
    sudo rm -rf "$dir/web/modules/"
    echo "rm modules"
    sudo rm -rf "$dir/web/content/"
    echo "rm content"
    sudo rm -rf "$dir/web/themes/"
    echo "rm themes"
    sudo rm -rf "$dir/web/translation/"
    echo "rm translation"
    sudo rm -rf "$dir/web/sites/default/sync/"
    echo "rm sync"
    sudo cp -R "$source_dir/portal/web/sites/default/sync/" "$dir/web/sites/default/"
    echo "cp sync"
    sudo cp -R "$source_dir/portal/web/modules/" "$dir/web/"
    echo "cp modules"
    sudo cp -R "$source_dir/portal/web/content/" "$dir/web/"
    echo "cp content"
    sudo cp -R "$source_dir/portal/web/themes/" "$dir/web/"
    echo "cp themes"
    sudo cp -R "$source_dir/portal/web/translation/" "$dir/web/"
    echo "cp translation"
    sudo cp -R "$source_dir/portal/composer.json" "$dir/"
    echo "cp composer"
    sudo cp -R "$source_dir/portal/patches/" "$dir/"
    echo "cp patches"
    cd "$dir/"
    sudo chown -R devportal:nginx "$dir/composer.json" "$dir/patches/" "$dir/web/modules/" "$dir/web/content/" "$dir/web/themes/" "$dir/web/translation/" "$dir/web/sites/default/sync/"
    sudo chmod -R 777 "$dir"
    read -p "Do you want to run 'composer up'? (y/n): " run_composer_up
    if [[ "$run_composer_up" == "y" || "$run_composer_up" == "Y" ]]; then
        composer up
    fi

    read -p "Do you want to run 'drush cim'? (y/n): " run_drush_cim
    if [[ "$run_drush_cim" == "y" || "$run_drush_cim" == "Y" ]]; then
        "$dir/vendor/drush/drush/drush" cim -y
    fi

    read -p "Do you want to run 'drush cr'? (y/n): " run_drush_cr
    if [[ "$run_drush_cr" == "y" || "$run_drush_cr" == "Y" ]]; then
        "$dir/vendor/drush/drush/drush" cr
    fi

    read -p "Do you want to run 'drush updb'? (y/n): " run_drush_updb
    if [[ "$run_drush_updb" == "y" || "$run_drush_updb" == "Y" ]]; then
        "$dir/vendor/drush/drush/drush" updb -y
    fi

    read -p "Do you want to run 'drush locale:update'? (y/n): " run_drush_locale_update
    if [[ "$run_drush_locale_update" == "y" || "$run_drush_locale_update" == "Y" ]]; then
        "$dir/vendor/drush/drush/drush" locale:update -y
    fi

    read -p "Do you want to run 'drush locale:import ar'? (y/n): " run_drush_locale_import
    if [[ "$run_drush_locale_import" == "y" || "$run_drush_locale_import" == "Y" ]]; then
        "$dir/vendor/drush/drush/drush" locale:import ar "$dir/web/translation/ar.po" --type=customized --override=all -y
    fi

    read -p "Do you want to run 'drush cr' again? (y/n): " run_drush_cr_again
    if [[ "$run_drush_cr_again" == "y" || "$run_drush_cr_again" == "Y" ]]; then
        "$dir/vendor/drush/drush/drush" cr
    fi
}




function php() {

    echo ""
    echo "Select the PHP Version:"
    echo "1) PHP 7.4"
    echo "2) PHP 8.0"
    echo "3) PHP 8.1"
    read -p "Please enter the PHP version number: " PHP_VERSION
    sleep 5

    case "$PHP_VERSION" in
        1)
            if [ "$OS_VERSION" == 1 ] || [ "$OS_VERSION" == 3 ]; then
                echo "$PHP_NAME"
                echo "$PHP_NAME OS (1 or 3) option selected 1."
                echo "You have selected CentOS 7 or Red Hat 7 and PHP 7.4."
                echo "Installing PHP version 7.4 on CentOS 7 or Red Hat 7"
                # Add commands to install PHP version 7.4 on CentOS 7 or Red Hat 7
                sudo yum install epel-release -y
                sudo yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y
                sudo yum install yum-utils -y
                sudo yum-config-manager --enable remi-php74
                sudo yum install php php-bcmath php-common php-cli php-fpm php-gd php-json php-mbstring php-mysqlnd php-opcache php-pdo php-process php-xml php-xmlrpc php-pgsql -y
                sudo cp /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.bak

                # Replace the user and group values with 'nginx' in the www.conf file
                sudo sed -i 's/^user = .*/user = nginx/' /etc/php-fpm.d/www.conf
                sudo sed -i 's/^group = .*/group = nginx/' /etc/php-fpm.d/www.conf
                sudo sed -i 's/^listen = .*/listen = 127.0.0.1:9000/' /etc/php-fpm.d/www.conf



                # Restart PHP-FPM service for changes to take effect
                sudo systemctl enable php-fpm.service
                sudo systemctl restart php-fpm
                echo "$PHP_NAME"
                echo "$PHP_NAME option selected 1 is end ."
            elif [ "$OS_VERSION" == 2 ] || [ "$OS_VERSION" == 4 ]; then
                PHP_NAME="PHP 7.4"
                echo "$PHP_NAME"
                echo "$PHP_NAME OS (2 or 4) option selected 1."
                echo "You have selected CentOS 8 or Red Hat 8 and PHP 7.4."
                echo "Installing PHP version 7.4 on CentOS 8 or Red Hat 8"
                # Add commands to install PHP version 7.4 on CentOS 8 or Red Hat 8
                sudo dnf update -y
                sudo dnf install -y epel-release
                sudo dnf install -y dnf-utils http://rpms.remirepo.net/enterprise/remi-release-8.rpm
                sudo dnf module reset php
                sudo dnf module enable php:remi-7.4 -y
                sudo dnf install -y php php-bcmath php-common php-cli php-fpm php-gd php-json php-mbstring php-mysqlnd php-opcache php-pdo php-process php-xml php-xmlrpc php-pgsql -y
                echo "PHP 7.4 installed successfully."
                sudo cp /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.bak

                # Replace the user and group values with 'nginx' in the www.conf file
                sudo sed -i 's/^user = .*/user = nginx/' /etc/php-fpm.d/www.conf
                sudo sed -i 's/^group = .*/group = nginx/' /etc/php-fpm.d/www.conf
                sudo sed -i 's/^listen = .*/listen = 127.0.0.1:9000/' /etc/php-fpm.d/www.conf


                # Restart PHP-FPM service for changes to take effect
                sudo systemctl enable php-fpm.service
                sudo systemctl restart php-fpm
                echo "$PHP_NAME"
                echo "$PHP_NAME option selected 1 is end ."
            fi

            ;;

        2)

            if [ "$OS_VERSION" == 1 ] || [ "$OS_VERSION" == 3 ]; then
                echo "$PHP_NAME"
                echo "$PHP_NAME OS (1 or 3) option selected 2."
                echo "You have selected CentOS 7 or Red Hat 7 and PHP 8.0."
                echo "Installing PHP version 8.0 on CentOS 7 or Red Hat 7"
                # Add commands to install PHP version 8.0 on CentOS 7 or Red Hat 7
                sudo yum install epel-release -y
                sudo yum-config-manager --enable remi-php80
                sudo yum install php php-bcmath php-common php-cli php-fpm php-gd php-json php-mbstring php-mysqlnd php-opcache php-pdo php-process php-xml php-xmlrpc php-pgsql -y
                sudo cp /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.bak

                # Replace the user and group values with 'nginx' in the www.conf file
                sudo sed -i 's/^user = .*/user = nginx/' /etc/php-fpm.d/www.conf
                sudo sed -i 's/^group = .*/group = nginx/' /etc/php-fpm.d/www.conf
                sudo sed -i 's/^listen = .*/listen = 127.0.0.1:9000/' /etc/php-fpm.d/www.conf


                # Restart PHP-FPM service for changes to take effect
                sudo systemctl enable php-fpm.service
                sudo systemctl restart php-fpm
                echo "$PHP_NAME"
                echo "$PHP_NAME OS (1 or 3) option selected 2 end."
            elif [ "$OS_VERSION" == 2 ] || [ "$OS_VERSION" == 4 ]; then
                PHP_NAME="PHP 8.0"
                echo "$PHP_NAME"
                echo "$PHP_NAME OS (2 or 4) option selected 2 start."
                echo "You have selected CentOS 8 or Red Hat 8 and PHP 8.0."
                echo "Installing PHP version 8.0 on CentOS 8 or Red Hat 8"
                # Add commands to install PHP version 8.0 on CentOS 8 or Red Hat 8
                sudo dnf update -y
                sudo dnf install -y epel-release
                sudo dnf install -y dnf-utils http://rpms.remirepo.net/enterprise/remi-release-8.rpm
                sudo dnf module reset php
                sudo dnf module enable php:remi-8.0 -y
                sudo dnf install -y php php-bcmath php-common php-cli php-fpm php-gd php-json php-mbstring php-mysqlnd php-opcache php-pdo php-process php-xml php-xmlrpc php-pgsql
                echo "PHP 8.0 installed successfully."
                sudo cp /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.bak

                # Replace the user and group values with 'nginx' in the www.conf file
                sudo sed -i 's/^user = .*/user = nginx/' /etc/php-fpm.d/www.conf
                sudo sed -i 's/^group = .*/group = nginx/' /etc/php-fpm.d/www.conf
                sudo sed -i 's/^listen = .*/listen = 127.0.0.1:9000/' /etc/php-fpm.d/www.conf


                # Restart PHP-FPM service for changes to take effect
                sudo systemctl enable php-fpm.service
                sudo systemctl restart php-fpm
                echo "$PHP_NAME"
                echo "$PHP_NAME OS (2 or 4) option selected 2 end."
            fi
            ;;
        3)
            if [ "$OS_VERSION" == 1 ] || [ "$OS_VERSION" == 3 ]; then
                echo "$PHP_NAME"
                echo "$PHP_NAME OS (1 or 3) option selected 3 start."
                echo "You have selected CentOS 7 or Red Hat 7 and PHP 8.1."
                echo "Installing PHP version 8.1 on CentOS 7 or Red Hat 7"
                # Add commands to install PHP version 8.1 on CentOS 7 or Red Hat 7
                sudo yum install epel-release -y
                sudo yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y
                sudo yum install yum-utils -y
                sudo yum-config-manager --enable remi-php81
                sudo yum install php php-bcmath php-common php-cli php-fpm php-gd php-json php-mbstring php-mysqlnd php-opcache php-pdo php-process php-xml php-xmlrpc php-pgsql -y
                sudo cp /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.bak

                # Replace the user and group values with 'nginx' in the www.conf file
                sudo sed -i 's/^user = .*/user = nginx/' /etc/php-fpm.d/www.conf
                sudo sed -i 's/^group = .*/group = nginx/' /etc/php-fpm.d/www.conf
                sudo sed -i 's/^listen = .*/listen = 127.0.0.1:9000/' /etc/php-fpm.d/www.conf


                # Restart PHP-FPM service for changes to take effect
                sudo systemctl enable php-fpm.service
                sudo systemctl restart php-fpm
                echo "$PHP_NAME"
                echo "$PHP_NAME OS (1 or 3) option selected 3 end."
            elif [ "$OS_VERSION" == 2 ] || [ "$OS_VERSION" == 4 ]; then
                PHP_NAME="PHP 8.1"
                echo "$PHP_NAME"
                echo "$PHP_NAME OS (2 or 4) option selected 3 start."

                echo "You have selected CentOS 8 or Red Hat 8 and PHP 8.1."
                echo "Installing PHP version 8.1 on CentOS 8 or Red Hat 8"
                # Add commands to install PHP version 8.1 on CentOS 8 or Red Hat 8
                sudo dnf update -y
                echo "update"
                sudo dnf install -y epel-release
                echo "install epel-release"
                sudo dnf install -y dnf-utils http://rpms.remirepo.net/enterprise/remi-release-8.rpm
                echo "install remi for php"
                sudo dnf module reset php -y
                echo "reset PHP"
                sudo dnf module enable php:remi-8.1 -y
                echo "enable PHP"
                sudo dnf install -y php php-bcmath php-common php-cli php-fpm php-gd php-json php-mbstring php-mysqlnd php-opcache php-pdo php-process php-xml php-xmlrpc php-pgsql
                echo "install PHP"
                #echo "PHP version is $(sudo php --version)."
                echo "PHP 8.1 installed successfully."
                sudo cp /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.bak
                echo "take a backup from php-fpm.d/www.conf"
                # Replace the user and group values with 'nginx' in the www.conf file
                sudo sed -i 's/^user = .*/user = nginx/' /etc/php-fpm.d/www.conf
                sudo sed -i 's/^group = .*/group = nginx/' /etc/php-fpm.d/www.conf
                sudo sed -i 's/^listen = .*/listen = 127.0.0.1:9000/' /etc/php-fpm.d/www.conf

                echo "change user and group on FPM configration file"
                # Restart PHP-FPM service for changes to take effect
                sudo systemctl enable php-fpm.service
                echo "restart PHP-FPM service for changes to take effect"
                sudo systemctl restart php-fpm
                echo "$PHP_NAME"
                echo "$PHP_NAME OS (2 or 4) option selected 3 end."

            fi
            ;;

        *)
            echo "Invalid PHP version selection."
            exit 1
            ;;
    esac
    echo "Script execution finished."

}

##################################################################################
function installDevPortal() {

    echo ""
    echo "Do you need to install kickstart Drupal or Pull custom portal code from the repo ?"
    echo "1)- kickstart Portal "
    echo "2)- Custome portal "
    read -p "Please enter the option: " DRUPAL_OPTION
    case "$DRUPAL_OPTION" in
        1)   
            echo ""
            echo "Select the Drupal Version:"
            echo "1) Drupal 8"
            echo "2) Drupal 9"
            read -p "Please enter the Drupal version number: " DRUPAL_VERSION
            sleep 5
        
            case "$DRUPAL_VERSION" in
                1)
                    DRUPAL_NAME="Drupal 8"
                    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
                    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
                    php -r "unlink('composer-setup.php');"
                    
                    mkdir -p /var/www
                    adduser devportal
                    chown -R devportal:devportal /var/www
        
                    cd /tmp/
                    wget -O drush.phar https://github.com/drush-ops/drush-launcher/releases/latest/download/drush.phar
                    yes|mv drush.phar /usr/local/bin/drush
        
                    PACKAGISTIP=$(dig packagist.org +short)
                    echo "$PACKAGISTIP packagist.org" >>/etc/hosts
        
                    sudo su - devportal -c 'cd /var/www && echo "export COMPOSER_MEMORY_LIMIT=2G" >> ~devportal/.bash_profile && source ~/.bash_profile && composer create-project apigee/devportal-kickstart-project:8.x-dev devportal --no-interaction && cd /var/www/devportal/web/sites/default && yes |cp default.settings.php settings.php && chmod 660 settings.php'
                    cd /var/www/devportal/web/sites/default && chown -R devportal:nginx settings.php
                    cd /var/www/devportal/web
                    chown -R devportal:nginx .
                    find . -type d -exec chmod u=rwx,g=rx,o= '{}' \;
                    find . -type f -exec chmod u=rw,g=r,o= '{}' \;
        
                    cd /var/www/devportal/web/sites/default && mkdir files
        
                    chown -R devportal:nginx .
                    find . -type d -exec chmod ug=rwx,o= '{}' \;
                    find . -type f -exec chmod ug=rw,o= '{}' \;
        
                    chcon -R -t httpd_sys_content_rw_t /var/www/devportal/web/sites/default
                    chcon -R -t httpd_sys_content_rw_t /var/www/devportal/web/sites/default/files 
                    chcon -R -t httpd_sys_content_rw_t /var/www/devportal/web/sites/default/settings.php
        
                    mkdir /var/www/private
                    cd /var/www/private
        
                    chown -R devportal:nginx .
                    find . -type d -exec chmod ug=rwx,o= '{}' \;
                    find . -type f -exec chmod ug=rw,o= '{}' \;
                    chcon -R -t httpd_sys_content_rw_t /var/www/private
        
                    echo "\$settings['file_private_path'] = '/var/www/private';" >>/var/www/devportal/web/sites/default/settings.php
        
                    setsebool -P httpd_can_network_connect on
                    #chmod 644 /var/www/devportal/web/sites/default/settings.php
                    #chmod 755 /var/www/devportal/web/sites/default
        
                    ;;
        
                2)
                    DRUPAL_NAME="Drupal 9"
                    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
                    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
                    php -r "unlink('composer-setup.php');"
                    
                    mkdir -p /var/www
                    adduser devportal
                    chown -R devportal:devportal /var/www
        
                    cd /tmp/
                    wget -O drush.phar https://github.com/drush-ops/drush-launcher/releases/latest/download/drush.phar
                    yes|mv drush.phar /usr/local/bin/drush
        
                    PACKAGISTIP=$(dig packagist.org +short)
                    echo "$PACKAGISTIP packagist.org" >>/etc/hosts
                    folder_path="/var/www/devportal"
        
                    if [ -d "$folder_path" ]; then
                        # If the folder exists, prompt for the action
                        read -p "Folder already exists. Do you want to (1) Delete or (2) Rename to .backup? (Enter 1 or 2): " action
        
                        if [ "$action" = "1" ]; then
                            # Delete the folder if the user chooses option 1
                            sudo rm -rf "$folder_path"
                            echo "Folder deleted successfully."
                        elif [ "$action" = "2" ]; then
                            # Rename the folder to .backup if the user chooses option 2
                            sudo mv "$folder_path" "${folder_path}.backup"
                            echo "Folder renamed to ${folder_path}.backup"
                        else
                            echo "Invalid choice. No action taken."
                        fi
                    fi
        
        
                    sudo su - devportal -c 'cd /var/www && echo "export COMPOSER_MEMORY_LIMIT=2G" >> ~devportal/.bash_profile && source ~/.bash_profile && composer create-project apigee/devportal-kickstart-project:9.x-dev devportal --no-interaction && cd /var/www/devportal/web/sites/default && yes |cp default.settings.php settings.php && chmod 660 settings.php'
                    cd /var/www/devportal/web/sites/default && chown -R devportal:nginx settings.php
                    cd /var/www/devportal/web
                    chown -R devportal:nginx .
                    find . -type d -exec chmod u=rwx,g=rx,o= '{}' \;
                    find . -type f -exec chmod u=rw,g=r,o= '{}' \;
        
                    cd /var/www/devportal/web/sites/default && mkdir files
        
                    chown -R devportal:nginx .
                    find . -type d -exec chmod ug=rwx,o= '{}' \;
                    find . -type f -exec chmod ug=rw,o= '{}' \;
        
                    chcon -R -t httpd_sys_content_rw_t /var/www/devportal/web/sites/default
                    chcon -R -t httpd_sys_content_rw_t /var/www/devportal/web/sites/default/files 
                    chcon -R -t httpd_sys_content_rw_t /var/www/devportal/web/sites/default/settings.php
                    folder_path_2="/var/www/private"
        
                    if [ -d "$folder_path_2" ]; then
                        # If the folder exists, prompt for the action
                        read -p "Folder already exists. Do you want to (1) Delete or (2) Rename to .backup? (Enter 1 or 2): " action
        
                        if [ "$action" = "1" ]; then
                            # Delete the folder if the user chooses option 1
                            sudo rm -rf "$folder_path_2"
                            echo "Folder deleted successfully."
                        elif [ "$action" = "2" ]; then
                            # Rename the folder to .backup if the user chooses option 2
                            sudo mv "$folder_path_2" "${folder_path_2}.backup"
                            echo "Folder renamed to ${folder_path_2}.backup"
                        else
                            echo "Invalid choice. No action taken."
                        fi
                    fi
        
                    mkdir /var/www/private
                    cd /var/www/private
        
                    chown -R devportal:nginx .
                    find . -type d -exec chmod ug=rwx,o= '{}' \;
                    find . -type f -exec chmod ug=rw,o= '{}' \;
                    chcon -R -t httpd_sys_content_rw_t /var/www/private
        
                    echo "\$settings['file_private_path'] = '/var/www/private';" >>/var/www/devportal/web/sites/default/settings.php
        
                    setsebool -P httpd_can_network_connect on
                    #chmod 644 /var/www/devportal/web/sites/default/settings.php
                    #chmod 755 /var/www/devportal/web/sites/default
        
                    ;;
        
        
                *)
                    echo "Invalid Drupal version selection."
                    exit 1
                    ;;
            esac
            ;;
    2)
        
        clone_repo
        update_devportal
        ;;
    *)
        echo "i dont know!"
        ;;
    
 esac       




}

##################################################################################



function firwall() {
    local firewall="Firewall"

    echo "Installing $firewall..."
    # Add installation commands for the Firewall
    # Your Firewall installation commands here
    sudo systemctl start firewalld
    sudo systemctl status firewalld
    firewall-cmd --list-services
    firewall-cmd --add-service={http,https,ssh,postgresql,mysql} --permanent
    firewall-cmd --reload
    firewall-cmd --list-all
    if sudo systemctl status firewalld | grep -q "running" ; then
        echo "11- install firwall and run service running"
    else
        echo "11- install firwall and run service have an issue please stop script and cheeck"
        exit
    fi
}

###################################################################################
function nginxconfigration() {
    yum install nginx -y
    sudo systemctl restart nginx.service
    sudo systemctl enable nginx.service
    if sudo systemctl status nginx.service | grep -q "running" ; then
        echo "9- install nginx and run service running"
    else
        echo "9- install nginx and run service have an issue please stop script and cheeck"
        exit
    fi
    sudo find /etc/nginx/conf.d/ -maxdepth 1 -type f -name "*.conf" -exec mv -n {} {}.bkp \;
    sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bkp
    sudo curl https://raw.githubusercontent.com/ahmedalazazy/auto/main/nginxrhel  -o /etc/nginx/nginx.conf
    sudo curl https://raw.githubusercontent.com/ahmedalazazy/auto/main/nginxconfigration -o /etc/nginx/conf.d/drupal-nginx.conf
    sudo systemctl restart nginx.service
    NGNGNGSTATUS=$(sudo systemctl status nginx.service )
    if echo "$NGNGNGSTATUS" | grep -q "running" ; then
        echo "14- nginx up and run service running"

    else
        echo "14- nginx service not running please stop script and cheeck"
        exit
    fi
}



# Function to configure PostgreSQL for remote access
function configure_postgresql() {

    local PGV=$PGV
    local PG_CONF="/var/lib/pgsql/${PGV}/data/postgresql.conf"
    local PG_HBA="/var/lib/pgsql/${PGV}/data/pg_hba.conf"
    echo "$PG_CONF"
    echo "$PG_HBA"
    echo "PG_VERSION"
    sudo chown -R postgres:postgres /var/lib/pgsql/"${PGV}"/data/
    # Enable listening on all interfaces in postgresql.conf
    sudo sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"

    # Allow remote access in pg_hba.conf
    echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a "$PG_HBA" > /dev/null

    # Restart PostgreSQL to apply the changes
    sudo systemctl restart postgresql

    echo "PostgreSQL has been configured for remote access."
}

# Function to create a database and user
function create_database_and_user_pg() {
    read -p "Enter the name of the database you want to create: " DATABASE_NAME
    read -p "Enter the username for the new database user: " DATABASE_USER
    read -s -p "Enter a password for the new user: " DATABASE_PASSWORD
    echo

    cd /var/lib/pgsql/"${PGV}"/data/

    # Create the database
    sudo -u postgres psql -c "CREATE DATABASE $DATABASE_NAME;"

    # Create the user and set the password
    sudo -u postgres psql -c "CREATE USER $DATABASE_USER WITH PASSWORD '$DATABASE_PASSWORD';"

    # Grant all privileges to the user on the database
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DATABASE_NAME TO $DATABASE_USER;"

    echo "Database and user have been created and configured."
}


function create_database_and_user_pg_mysql_mariadb() {

    local MYSQL_VERSION=$(mysql --version | awk '{print $3}')
    read -p "Please type the DB root password you are created on the top: " ROOTPASSWORD;
    read -p "Please type the new DB name : " DB;
    read -p "Please type the new DB USER : " USER;
    read -p "Please type the new DB PASS : " PASS;
    echo "Create the database"     # Create the database
    mysql -uroot -p'$ROOTPASSWORD' -e "CREATE DATABASE $DB CHARACTER SET utf8 COLLATE utf8_general_ci";
    echo "Create the user and set the password"    # Create the user and set the password
    mysql -uroot -p'$ROOTPASSWORD' -e "CREATE USER $USER@'localhost' IDENTIFIED BY '$PASS'";
    echo "Grant all privileges to the user on the database" #Grant all privileges to the user on the database
    mysql -uroot -p'$ROOTPASSWORD' -e "GRANT ALL PRIVILEGES ON * . * TO '$USER'@'localhost' IDENTIFIED BY '$PASS'";

}


###################################################################################
function installDB() {

    echo ""
    echo "Select the Database Type:"
    echo "1) MySQL"
    echo "2) PostgreSQL"
    echo "3) MariaDB"
    read -p "Please enter the database type number: " DB_TYPE_NUMBER
    if [ "$DB_TYPE_NUMBER" == "1" ]; then
        DBTYPE="MySQL"
    elif [ "$DB_TYPE_NUMBER" == "2" ]; then
        DBTYPE="PostgreSQL"
    elif [ "$DB_TYPE_NUMBER" == "3" ]; then
        DBTYPE="MariaDB"
    else
        echo "Invalid database type selection."
        return 1
    fi

    if [ "$DBTYPE" == "MySQL" ]; then
        echo "Installing MySQL..."
        # Add installation commands for MySQL
        # Your MySQL/MariaDB installation commands here
        echo ""
        echo "Select the MySQL Version:"
        echo "1) MySQL 5.7"
        echo "2) MySQL 8.0"
        echo "3) MySQL 8.0.23"
        read -p "Please enter the MySQL version number: " MYSQL_VERSION
        sleep 5


        case "$MYSQL_VERSION" in
            1)
                MYSQL_NAME="MySQL 5.7"
                if [ "$OS_VERSION" == 1 ] || [ "$OS_VERSION" == 3 ]; then
                    echo "You have selected CentOS 7 or Red Hat 7."
                    echo "Installing MySQL version 5.7"
                    sudo yum install -y https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm
                    sudo yum install -y mysql-community-server
                    sudo systemctl enable mysqld
                    sudo systemctl start mysqld
                    echo "8-create DB & add new user done"
                    sleep 6
                    # Check if the parameter already exists in the file
                    if grep -q "max_allowed_packet" "$SERVER_CONF"; then
                        echo "max_allowed_packet parameter already exists. No changes needed."
                        return
                    fi
                    # Add the max_allowed_packet parameter to the [server] section
                    sudo sed -i '/\[server\]/a max_allowed_packet=64M' "$SERVER_CONF"
                    echo "max_allowed_packet parameter added to $SERVER_CONF"
                    create_database_and_user_pg_mysql_mariadb

                elif [ "$OS_VERSION" == 2 ] || [ "$OS_VERSION" == 4 ]; then
                    echo "You have selected CentOS 8 or Red Hat 8."
                    # Add your commands specific to CentOS 8 or Red Hat 8 here
                    echo "Installing MySQL version 5.7"
                    sudo dnf install -y https://dev.mysql.com/get/mysql57-community-release-el8-3.noarch.rpm
                    sudo dnf install -y mysql-community-server
                    sudo systemctl enable mysqld
                    sudo systemctl start mysqld
                    # Check if the parameter already exists in the file
                    if grep -q "max_allowed_packet" "$SERVER_CONF"; then
                        echo "max_allowed_packet parameter already exists. No changes needed."
                        return
                    fi

                    # Add the max_allowed_packet parameter to the [server] section
                    sudo sed -i '/\[server\]/a max_allowed_packet=64M' "$SERVER_CONF"
                    echo "max_allowed_packet parameter added to $SERVER_CONF"
                    create_database_and_user_pg_mysql_mariadb
                else
                    echo "I don't know the selected OS version."
                fi
                ;;

            2)
                MYSQL_NAME="MySQL 8.0"
                if [ "$OS_VERSION" == 1 ] || [ "$OS_VERSION" == 3 ]; then
                    echo "You have selected CentOS 7 or Red Hat 7."
                    echo "Installing MySQL version 8.0"
                    sudo yum install -y https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm
                    sudo yum install -y mysql-community-server
                    sudo systemctl enable mysqld
                    sudo systemctl start mysqld
                    # Check if the parameter already exists in the file
                    if grep -q "max_allowed_packet" "$SERVER_CONF"; then
                        echo "max_allowed_packet parameter already exists. No changes needed."
                        return
                    fi

                    # Add the max_allowed_packet parameter to the [server] section
                    sudo sed -i '/\[server\]/a max_allowed_packet=64M' "$SERVER_CONF"
                    echo "max_allowed_packet parameter added to $SERVER_CONF"
                    create_database_and_user_pg_mysql_mariadb
                elif [ "$OS_VERSION" == 2 ] || [ "$OS_VERSION" == 4 ]; then
                    echo "You have selected CentOS 8 or Red Hat 8."
                    # Add your commands specific to CentOS 8 or Red Hat 8 here
                    echo "Installing MySQL version 8.0"
                    sudo dnf install -y https://dev.mysql.com/get/mysql80-community-release-el8-3.noarch.rpm
                    sudo dnf install -y mysql-community-server
                    sudo systemctl enable mysqld
                    sudo systemctl start mysqld
                    # Check if the parameter already exists in the file
                    if grep -q "max_allowed_packet" "$SERVER_CONF"; then
                        echo "max_allowed_packet parameter already exists. No changes needed."
                        return
                    fi

                    # Add the max_allowed_packet parameter to the [server] section
                    sudo sed -i '/\[server\]/a max_allowed_packet=64M' "$SERVER_CONF"
                    echo "max_allowed_packet parameter added to $SERVER_CONF"
                    create_database_and_user_pg_mysql_mariadb
                else
                    echo "I don't know the selected OS version."
                fi
                ;;
            *)
                echo "Invalid MySQL version selection."
                exit 1
                ;;
        esac



    elif [ "$DBTYPE" == "PG" ] || [ "$DBTYPE" == "PostgreSQL" ]; then
        echo "Installing PostgreSQL..."
        # Add installation commands for PostgreSQL
        # Your PostgreSQL installation commands here
            echo ""
            echo "Select the PostgreSQL Version:"
            echo "1) PostgreSQL 12"
            echo "2) PostgreSQL 13"
            echo "3) PostgreSQL 14"
            echo "4) PostgreSQL 15"
            read -p "Please enter the PostgreSQL version number: " PG_VERSION
            sleep 5
            local PG_VERSION=$PG_VERSION
            if [ "$PG_VERSION" == 1 ]; then
                PGV="12"
                local PGV="$PGV"
            elif [ "$PG_VERSION" == 2 ]; then
                PGV="13"
                local PGV="$PGV"
            elif [ "$PG_VERSION" == 3 ]; then
                PGV="14"
                local PGV="$PGV"
            elif [ "$PG_VERSION" == 4 ]; then
                PGV="15"
                local PGV="$PGV"
            else
                echo "Invalid PostgreSQL version selection."
                return 1
            fi


            case "$PG_VERSION" in
                1)  

                    if [ "$OS_VERSION" == 1 ] || [ "$OS_VERSION" == 3 ]; then
                        echo "You have selected CentOS 7 or Red Hat 7."
                        echo "Installing Postgres version 12"
                        sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
                        sudo yum install -y postgresql12-server postgresql12-devel
                        sudo /usr/pgsql-12/bin/postgresql-12-setup initdb
                        sudo systemctl enable postgresql-12
                        sudo systemctl restart postgresql-12
                        configure_postgresql
                        create_database_and_user_pg
                    elif [ "$OS_VERSION" == 2 ] || [ "$OS_VERSION" == 4 ]; then
                        echo "You have selected CentOS 8 or Red Hat 8."
                        # Add your commands specific to CentOS 8 or Red Hat 8 here
                        echo "Installing Postgres version 12"
                        sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
                        sudo dnf -qy module disable postgresql
                        sudo dnf install -y postgresql12-server postgresql12-devel
                        sudo /usr/pgsql-12/bin/postgresql-12-setup initdb
                        sudo systemctl enable postgresql-12
                        sudo systemctl restart postgresql-12
                        configure_postgresql
                        create_database_and_user_pg
                    else
                        echo "I don't know the selected OS version."
                    fi
                    ;;
            
                2)
                    if [ "$OS_VERSION" == 1 ] || [ "$OS_VERSION" == 3 ]; then
                        echo "You have selected CentOS 7 or Red Hat 7."
                        echo "Installing Postgres version 13"
                        sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
                        sudo yum install -y postgresql13-server postgresql13-devel
                        sudo /usr/pgsql-13/bin/postgresql-13-setup initdb
                        sudo systemctl enable postgresql-13
                        sudo systemctl restart postgresql-13
                        configure_postgresql
                        create_database_and_user_pg

                    elif [ "$OS_VERSION" == 2 ] || [ "$OS_VERSION" == 4 ]; then
                        echo "You have selected CentOS 8 or Red Hat 8."
                        # Add your commands specific to CentOS 8 or Red Hat 8 here
                        echo "Installing Postgres version 13"
                        sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
                        sudo dnf -qy module disable postgresql
                        sudo dnf install -y postgresql13-server postgresql13-devel
                        sudo /usr/pgsql-13/bin/postgresql-13-setup initdb
                        sudo systemctl enable postgresql-13
                        sudo systemctl restart postgresql-13
                        configure_postgresql
                        create_database_and_user_pg
                    else
                        echo "I don't know the selected OS version."
                    fi
                    ;;
            
                3)
                    echo "Installing Postgres version 14"
                    # Add commands to install Postgres version 14
                    if [ "$OS_VERSION" == 1 ] || [ "$OS_VERSION" == 3 ]; then
                        echo "You have selected CentOS 7 or Red Hat 7."
                        echo "Installing Postgres version 14"
                        sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
                        sudo yum install -y postgresql14-server postgresql14-devel
                        sudo /usr/pgsql-14/bin/postgresql-14-setup initdb
                        sudo systemctl enable postgresql-14
                        sudo systemctl restart postgresql-14
                        sudo systemctl status postgresql-14
                        configure_postgresql
                        create_database_and_user_pg
                    elif [ "$OS_VERSION" == 2 ] || [ "$OS_VERSION" == 4 ]; then
                        echo "You have selected CentOS 8 or Red Hat 8."
                        # Add your commands specific to CentOS 8 or Red Hat 8 here
                        echo "Installing Postgres version 14"
                        sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
                        sudo dnf -qy module disable postgresql
                        sudo dnf install -y postgresql14-server postgresql14-devel
                        sudo /usr/pgsql-14/bin/postgresql-14-setup initdb
                        sudo systemctl enable postgresql-14
                        sudo systemctl restart postgresql-14
                        configure_postgresql
                        create_database_and_user_pg
                    else
                        echo "I don't know the selected OS version."
                    fi
                    ;;
                4)
                    echo "Installing Postgres version 15"
                    if [ "$OS_VERSION" == 1 ] || [ "$OS_VERSION" == 3 ]; then
                        echo "You have selected CentOS 7 or Red Hat 7."
                        echo "Installing Postgres version 15"
                        sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
                        sudo yum install -y postgresql15-server postgresql15-devel
                        sudo /usr/pgsql-15/bin/postgresql-15-setup initdb
                        sudo systemctl enable postgresql-15
                        sudo systemctl restart postgresql-15
                        configure_postgresql
                        create_database_and_user_pg
                    elif [ "$OS_VERSION" == 2 ] || [ "$OS_VERSION" == 4 ]; then
                        echo "You have selected CentOS 8 or Red Hat 8."
                        # Add your commands specific to CentOS 8 or Red Hat 8 here
                        echo "Installing Postgres version 15"
                        sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
                        sudo dnf -qy module disable postgresql
                        sudo dnf install -y postgresql15-server postgresql15-devel
                        sudo /usr/pgsql-15/bin/postgresql-15-setup initdb
                        sudo systemctl enable postgresql-15
                        sudo systemctl restart postgresql-15
                        configure_postgresql
                        create_database_and_user_pg
                    else
                        echo "I don't know the selected OS version."
                    fi
                    ;;
                *)
                    echo "Invalid choice. Please select a valid option (1, 2, 3, or 4)."
                    ;;

            esac



    elif [ "$DBTYPE" == "MariaDB" ]; then
        echo "Installing MariaDB..."
        #Add installation commands for MariaDB
        Your MariaDB installation commands here
        echo ""
        echo "Select the MariaDB Version:"
        echo "1) MariaDB 10"
        echo "2) MariaDB 11"
        read -p "Please enter the MariaDB version number: " MariaDB_VERSION
        sleep 5

        case "$MariaDB_VERSION" in

            1)
                DB_NAME="MariaDB 10"
                # MariaDB installation commands
                if [ "$OS_VERSION" == 1 ] || [ "$OS_VERSION" == 3 ]; then
                    # Install the MariaDB GPG key
                    sudo rpm --import https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
                    # Add the MariaDB repository
                    sudo sh -c 'echo "[mariadb]" > /etc/yum.repos.d/MariaDB.repo'
                    sudo sh -c 'echo "name = MariaDB" >> /etc/yum.repos.d/MariaDB.repo'
                    sudo sh -c 'echo "baseurl = http://yum.mariadb.org/10.10/centos7-amd64" >> /etc/yum.repos.d/MariaDB.repo'
                    sudo sh -c 'echo "gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB" >> /etc/yum.repos.d/MariaDB.repo'
                    sudo sh -c 'echo "gpgcheck=1" >> /etc/yum.repos.d/MariaDB.repo'
                    # Install MariaDB server and client
                    sudo yum install mariadb-server mariadb-client
                    # Start the MariaDB server
                    sudo systemctl start mariadb
                    # Secure the MariaDB server
                    sudo mysql_secure_installation
                    # Check the status of the MariaDB server
                    sudo systemctl status mariadb
                    # Check if the parameter already exists in the file
                    if grep -q "max_allowed_packet" "$SERVER_CONF"; then
                        echo "max_allowed_packet parameter already exists. No changes needed."
                        return
                    fi

                    # Add the max_allowed_packet parameter to the [server] section
                    sudo sed -i '/\[server\]/a max_allowed_packet=64M' "$SERVER_CONF"
                    echo "max_allowed_packet parameter added to $SERVER_CONF"
                    create_database_and_user_pg_mysql_mariadb
                elif [ "$OS_VERSION" == 2 ] || [ "$OS_VERSION" == 4 ]; then
                    echo "You have selected CentOS 8 or Red Hat 8."
                    # Add your commands specific to CentOS 8 or Red Hat 8 here
                    echo "Installing MariaDB (latest)"
                    sudo dnf install -y mariadb-server
                    sudo systemctl enable mariadb
                    sudo systemctl start mariadb
                    # Check if the parameter already exists in the file
                    if grep -q "max_allowed_packet" "$SERVER_CONF"; then
                        echo "max_allowed_packet parameter already exists. No changes needed."
                        return
                    fi

                    # Add the max_allowed_packet parameter to the [server] section
                    sudo sed -i '/\[server\]/a max_allowed_packet=64M' "$SERVER_CONF"
                    echo "max_allowed_packet parameter added to $SERVER_CONF"
                    create_database_and_user_pg_mysql_mariadb
                else
                    echo "I don't know the selected OS version."
                fi
                ;;
            2)
                if [ "$OS_VERSION" == 1 ] || [ "$OS_VERSION" == 3 ]; then
                    # Install the MariaDB GPG key
                    sudo rpm --import https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
                    # Add the MariaDB repository
                    sudo sh -c 'echo "[mariadb]" > /etc/yum.repos.d/MariaDB.repo'
                    sudo sh -c 'echo "name = MariaDB" >> /etc/yum.repos.d/MariaDB.repo'
                    sudo sh -c 'echo "baseurl = http://yum.mariadb.org/11.2/centos7-amd64" >> /etc/yum.repos.d/MariaDB.repo'
                    sudo sh -c 'echo "gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB" >> /etc/yum.repos.d/MariaDB.repo'
                    sudo sh -c 'echo "gpgcheck=1" >> /etc/yum.repos.d/MariaDB.repo'
                    # Install MariaDB server and client
                    sudo yum install mariadb-server mariadb-client
                    # Start the MariaDB server
                    sudo systemctl start mariadb
                    # Secure the MariaDB server
                    sudo mysql_secure_installation
                    # Check the status of the MariaDB server
                    sudo systemctl status mariadb
                    # Check if the parameter already exists in the file
                    if grep -q "max_allowed_packet" "$SERVER_CONF"; then
                        echo "max_allowed_packet parameter already exists. No changes needed."
                        return
                    fi

                    # Add the max_allowed_packet parameter to the [server] section
                    sudo sed -i '/\[server\]/a max_allowed_packet=64M' "$SERVER_CONF"
                    echo "max_allowed_packet parameter added to $SERVER_CONF"
                    create_database_and_user_pg_mysql_mariadb
                elif [ "$OS_VERSION" == 2 ] || [ "$OS_VERSION" == 4 ]; then
                    echo "You have selected CentOS 8 or Red Hat 8."
                    # Add your commands specific to CentOS 8 or Red Hat 8 here
                    echo "Installing MariaDB (latest)"
                    sudo dnf install -y mariadb-server
                    sudo systemctl enable mariadb
                    sudo systemctl start mariadb
                    # Check if the parameter already exists in the file
                    if grep -q "max_allowed_packet" "$SERVER_CONF"; then
                        echo "max_allowed_packet parameter already exists. No changes needed."
                        return
                    fi

                    # Add the max_allowed_packet parameter to the [server] section
                    sudo sed -i '/\[server\]/a max_allowed_packet=64M' "$SERVER_CONF"
                    echo "max_allowed_packet parameter added to $SERVER_CONF"
                    create_database_and_user_pg_mysql_mariadb
                else
                    echo "I don't know the selected OS version."
                fi
                ;;

            *)
                echo "Invalid database version selection."
                exit 1
                ;;
        esac


    else
        echo "Invalid database type. Supported types: MySQL, PostgreSQL, MariaDB."
        return 1
    fi
}



function Select_the_OS_Version(){
    echo "Select the OS Version:"
    echo "1) CentOS 7"
    echo "2) CentOS 8"
    echo "3) Red Hat 7"
    echo "4) Red Hat 8"
    read -p "Please enter the OS version number: " OS_VERSION
    sleep 2
    local OS_VERSION=$OS_VERSION
    echo "Preparing OS"

    case "$OS_VERSION" in
        1 | 3)
            # Add your commands specific to CentOS 7 or Red Hat 7 here
            echo "You have selected CentOS 7 or Red Hat 7."
            OS_NAME="CentOS 7 / Red Hat 7"
            sudo yum update -y
            sudo yum install -y epel-release
            sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
            sudo yum install -y http://rpms.remirepo.net/enterprise/remi-release-7.rpm
            sudo yum update -y
            sudo yum install -y yum-utils git zip unzip wget htop vim nano git curl bash net-tools tree yum-utils firewalld gzip bind-utils -y
            ;;

        2 | 4)
            # Add your commands specific to CentOS 8 or Red Hat 8 here
            echo "You have selected CentOS 8 or Red Hat 8."
            OS_NAME="CentOS 8 / Red Hat 8"
            sudo dnf update -y
            sudo dnf install -y epel-release
            sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
            sudo dnf install -y http://rpms.remirepo.net/enterprise/remi-release-8.rpm
            sudo dnf update -y
            sudo dnf install -y yum-utils git zip unzip wget htop vim nano git curl bash net-tools tree yum-utils firewalld gzip bind-utils -y
            ;;

        *)
            echo "Invalid OS version selection."
            exit 1
            ;;

    esac

}


echo "Please chose what you need to do: "
echo "1) Install APigee DevPortal + DB" 
echo "2) Install Apigee DevPortal"
echo "3) Install DB"
echo "4) Update installation"
read -p "Please enter the Installation number: " InstallationNumber
case "$InstallationNumber" in

    1)
        #add function for DB and php and drupal and firwall
        Select_the_OS_Version
        php
        unset -f php
        installDB
        unset -f installDB
        installDevPortal
        unset -f installDevPortal
        nginxconfigration
        unset -f nginxconfigration
        firwall
        unset -f firwall
        ;;
    2)
        echo "Select the database type:"
        #add function for php and drupal and firwall
        Select_the_OS_Version
        php
        unset -f php
        installDevPortal
        unset -f installDevPortal
        nginxconfigration
        unset -f nginxconfigration
        sleep 5
        ;;
    3)
        echo "Select the database type:"
        #add function for DB
        Select_the_OS_Version
        installDB
        unset -f installDB
        sleep 5
        ;;
    4)
        echo "coming soon:"
        ;;

    *)
        echo "Invalid chose selection."
        exit 1
        ;;
        
esac

echo ""
echo "You have selected:"
echo "OS Version: $OS_NAME"
echo "PHP Version: $PHP_NAME"
echo "Drupal Version: $DRUPAL_NAME"
echo "MySQL Version: $MYSQL_NAME"
echo "PostgreSQL Version: $PG_NAME"
echo "MariaDB Version: $MARIADB_NAME"
echo ""
