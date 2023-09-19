#!/usr/bin/env python3

import csv
import subprocess
import os
import time

print("=" * 50)
time.sleep(5)
print("this script created By: Ahmed Alazazy Github: https://github.com/ahmedalazazy")
print("=" * 50)
time.sleep(5)
print("This script working to automate the ssl generation for multiple domain URLS")
print("=" * 50)
time.sleep(5)

# Function to create folders based on ENV column
def create_folders(env):
    if not os.path.exists(env):
        os.makedirs(env)

# Function to generate SSL certificates and remove ssl-config.conf files
def generate_ssl_certificates_and_clean(env, servicename, url, ip):
    # Create folders based on ENV
    create_folders(env)

    # Define ssl-config.conf content for each row
      
    ssl_config = f"""
[req]
default_bits = 2048
distinguished_name = req_distinguished_name
req_extensions = req_ext

[req_distinguished_name]
C = {C}
ST = {ST}
L = {L}
O = {O}
OU = {OU}
CN = {CN}
emailAddress = {emailAddress}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = {DNS}
"""

    # Print the configuration for debugging purposes
    print(f"Generating SSL certificate for {url} with the following configuration:")

    # Write ssl-config.conf to a file
    config_file_name = os.path.join(env, f'{servicename}-ssl-config.conf')
    with open(config_file_name, 'w') as config_file:
        config_file.write(ssl_config)

    openssl_cmd = (
        f"openssl req -new -newkey rsa:2048 -nodes -keyout {env}/{servicename}-key.pem "
        f"-out {env}/{servicename}-csr.csr -subj "
        f"'/C={C}/ST={ST}/L={L}/O={O}/OU={OU}/CN={url}/emailAddress={emailAddress}' "
        f"-config {config_file_name}"
    )
    
    subprocess.run(openssl_cmd, shell=True)

    print(f'SSL certificate {servicename} generated for {url} {ip} in {env}')
    
    # Remove ssl-config.conf file after generating certificates
    os.remove(config_file_name)
    
    # Read data from list.csv
with open('list.csv', 'r') as csvfile:
    csvreader = csv.DictReader(csvfile)
    for row in csvreader:
        env = row['ENV']
        servicename = row['SERVICENAME']
        url = row['URL']
        ip = row['IP']
        C =row['C']
        ST =row['ST']
        L =row['L']
        O =row['O']
        OU =row['OU']
        CN =row['URL']
        emailAddress =row['emailAddress']
        DNS = row['HOSTNAME']
        DNS2 = row['HOSTNAMEURL']

        # Generate SSL certificates and clean up ssl-config.conf
        generate_ssl_certificates_and_clean(env, servicename, url, ip)

print('SSL certificate generation completed.')
TARFI_CMD="find . -type f -name '*.csr' -exec tar -czf csr_files.tar.gz --transform 's|^\./||' {} +"
subprocess.run(TARFI_CMD, shell=True)

# Create the first tar file
TARFI_CMD2 = "find . -type f \( -name '*.csr' -o -name '*.pem' \) -exec tar -czf Fill_SSL_files.tar.gz --transform 's|^\./||' {} +"
subprocess.run(TARFI_CMD2, shell=True)
