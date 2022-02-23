#!/bin/bash

#MINTANINSPO="TERMINATE"
MINTANINSPO="MIGRATE"

input="file00.txt"

while IFS=, read VMNAME VMZONE PPRROJJECT; do

gcloud compute instances set-scheduling "$VMNAME" --maintenance-policy="$MINTANINSPO" --restart-on-failure --zone="$VMZONE" --project="$PPRROJJECT"

done <<< $( cat file00.txt)
