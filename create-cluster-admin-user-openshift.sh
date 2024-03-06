#!/bin/bash

# Function to generate a random password
generate_password() {
    # Generate a random string of 12 characters
    password=$(openssl rand -base64 12)
    # Remove special characters from the password
    password=$(echo "$password" | tr -d '/+=')
    echo "$password"
}

# Prompt the user to enter the OpenShift admin username, password, and URL
read -p "Enter the OpenShift admin username: " admin_username
read -s -p "Enter the password for $admin_username: " admin_password
read -p "Enter the URL for the OKD server: " okd_url

# Prompt the user to enter the username for the new OpenShift user
read -p "Enter the username for the new OpenShift user: " username

# Generate a random password for the new user
password=$(generate_password)

# Log in to OpenShift using the provided admin credentials and URL
oc login "$okd_url" -u "$admin_username" -p "$admin_password" --insecure-skip-tls-verify=true

# Create the new user in OpenShift using HTPasswd identity provider
oc get secret htpass-secret -ojsonpath={.data.htpasswd} -n openshift-config | base64 -d > users.htpasswd
cat users.htpasswd
oc create user "$username"
oc create identity htpasswd:"$username"
htpasswd -bB users.htpasswd "$username" "$password"
oc create useridentitymapping htpasswd:"$username" "$username"
oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd --dry-run=client -o yaml -n openshift-config | oc replace -f -

echo "User '$username' created with password: $password"
