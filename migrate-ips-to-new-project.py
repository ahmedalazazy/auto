#!/bin/python3
import csv, subprocess, sys, os
print("This script to Migrate IPS to anther Project and re asine to migrated machines ")
OR_PROJECT = input("PLease Type the Origenal project ID: ")
NEW_PROJECT = input("PLease Type the NEW PROJECT project ID: ")
filename = f"{OR_PROJECT}-ex-ips-to-move-{NEW_PROJECT}.csv"
subprocess.run(['/bin/bash', '-c', f'gcloud compute addresses list --project={OR_PROJECT} --filter="(TYPE=EXTERNAL)" --format="csv[no-heading](name,REGION,address_range())" > {filename}'])

with open(filename, 'r') as csvfile:
    datareader = csv.reader(csvfile)
    for row in datareader:
        ADDRESS_NAME = row[0]
        REGION = row[1]
        ADDRESS_RANGE = row[2]
        subprocess.run(['/bin/bash', '-c', f'VMNAME=$(gcloud compute addresses describe {ADDRESS_NAME} --project={OR_PROJECT} --format="csv[no-heading](users)") && VMZONE=$(gcloud compute instances describe "$VMNAME" --format="csv[no-heading](zone.scope())" --project={OR_PROJECT}) && gcloud compute instances delete-access-config "$VMNAME"--zone="$VMZONE"  --access-config-name="External NAT" --project={OR_PROJECT} '])
        subprocess.run(['/bin/bash', '-c', f'gcloud alpha compute addresses move {ADDRESS_NAME} --target-project={NEW_PROJECT} --region={REGION} --project={OR_PROJECT}'])
        subprocess.run(['/bin/bash', '-c', f'VMNAME=$(gcloud compute addresses describe {ADDRESS_NAME} --project={OR_PROJECT} --format="csv[no-heading](users)") && VMZONE=$(gcloud compute instances describe "$VMNAME" --format="csv[no-heading](zone.scope())" --project={OR_PROJECT}) && gcloud compute instances add-access-config $VMNAME --access-config-name="External NAT" --address={ADDRESS_RANGE} --project={NEW_PROJECT} '])

subprocess.run(['/bin/bash', '-c', f'rm -rf {filename}'])