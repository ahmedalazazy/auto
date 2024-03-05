#!/bin/bash

# Function to generate a random password
generate_password() {
    # Generate a random string of 12 characters
    password=$(openssl rand -base64 12)
    # Remove special characters from the password
    password=$(echo "$password" | tr -d '/+=')
    echo "$password"
}

# Prompt the user to enter the OpenShift login details
read -p "Enter the OpenShift admin username: " admin_username
read -s -p "Enter the password for $admin_username: " admin_password
read -p "Enter the URL for the OKD server: " okd_url

# Prompt the user to enter the username
read -p "Enter the username for the new OpenShift user: " username

# Generate a random password for the user
password=$(generate_password)

# Log in to OpenShift using the provided admin credentials and URL
oc login "$okd_url" -u "$admin_username" -p "$admin_password" --insecure-skip-tls-verify=true

# Create the user in OpenShift
oc create user "$username"

# Set the password for the user
oc create secret generic "${username}-password" --from-literal=password="$password"

# Assign administrative privileges to the user
oc adm policy add-cluster-role-to-user cluster-admin "$username"

echo "User '$username' created with password: $password"
