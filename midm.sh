#!/bin/bash

# Gathering all VMs names and delete the first line with "NAME" entry to keey only VM names.
gcloud beta compute machine-images list --format="table(NAME)" | sed '1d' | grep mfirmgt > midm.list

# Generate the neede old date in same machime imgaes format
OLDDATE=$(date -d "30 days ago" "+%Y-%m-%d-%H-%M-%S")
#OLDDATE=$(date -d '30 minutes ago' "+%Y-%m-%d-%H-%M-%S")

# Delete needed machine images.
while read -r NAME
do
    [ "${OLDDATE}" ">" "${NAME#*mfirmgt-}" ] && gcloud beta compute machine-images delete $NAME --quiet
done < midm.list

rm -rf midm.list
#to run evre time 1/h
#0 1 * * *s