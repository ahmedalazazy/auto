#!/bin/bash
# Gathering all VMs names and delete the first line with "NAME,ZONE" entries to keep only VM names and zones.
gcloud compute instances list --format="csv(NAME,ZONE)" --filter="labels:mcloudyimage" | sed '1d' >mmic.list
# Create machine images by looping to all VM names from the mic.list file.
while IFS=, NAME ZONE
do
 # Gathering the current date.
 TIMESTAMP=`date "+%Y-%m-%d-%H-%M-%S"`
 # Create the machine image.
 gcloud beta compute machine-images create $NAME-mfirmgt-$TIMESTAMP --source-instance $NAME --source-instance-zone $ZONE
done < mmic.list
rm -rf mmic.list
#to run evre 28 day on 12:00AM
#0 0 28 * *