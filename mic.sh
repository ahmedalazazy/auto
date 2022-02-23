#!/bin/bash

# Gathering all VMs names and delete the first line with "NAME,ZONE" entries to keep only VM names and zones.
gcloud compute instances list --format="table(NAME,ZONE)" --filter="labels:cloudyimage" | sed '1d' > mic.list

# Create machine images by looping to all VM names from the mic.list file.
while read -r NAME ZONE
do
 # Gathering the current date.
 TIMESTAMP=`date "+%Y-%m-%d-%H-%M-%S"`
 # Create the machine image.
 gcloud beta compute machine-images create $NAME-cloudyimage-$TIMESTAMP --source-instance $NAME --source-instance-zone $ZONE
done < mic.list

rm -rf mic.list
