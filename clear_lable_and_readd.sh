#!/bin/bash

NODEGROUB_LABLE="node-group-test"

input="file00.txt"

while IFS=, read VMNAME VMZONE PPRROJJECT

do
#
gcloud beta compute instances suspend "$VMNAME" --zone="$VMZONE" --project="$PPRROJJECT"
gcloud compute instances set-scheduling "$VMNAME" --clear-node-affinities --zone="$VMZONE" --project="$PPRROJJECT"
gcloud compute instances set-scheduling "$VMNAME" --node-group=$NODEGROUB_LABLE --zone="$VMZONE" --project="$PPRROJJECT"
gcloud beta compute instances resume "$VMNAME" --zone="$VMZONE" --project="$PPRROJJECT"
#
echo "$VMNAME,$VMZONE,$PPRROJJECT : DONE "
#
done <<< $( cat file00.txt)

