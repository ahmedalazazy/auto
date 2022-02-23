#!/bin/bash

# Gathering all VMs names and delete the first line with "NAME" entry to keey only VM names.
gcloud beta compute machine-images list --format="table(NAME)" | sed '1d' | grep cloudyimage > mid.list

# Generate the neede old date in same machime imgaes format
OLDDATE=$(date -d "60 days ago" "+%Y-%m-%d-%H-%M-%S")
#OLDDATE=$(date -d '30 minutes ago' "+%Y-%m-%d-%H-%M-%S")

# Delete needed machine images.
while read -r NAME
do
    [ "${OLDDATE}" ">" "${NAME#*cloudyimage-}" ] && gcloud beta compute machine-images delete $NAME --quiet
done < mid.list

rm -rf mid.list
