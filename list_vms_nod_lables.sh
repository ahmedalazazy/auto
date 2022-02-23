#!/usr/bin/env bash
read -p "Please Type the project NAME : " PPPROJECT;
gcloud compute instances list  --format="csv(NAME,ZONE,MACHINE_TYPE,STATUS,scheduling.nodeAffinities[values])" --project="$PPPROJECT"  > ${PPPROJECT}_list_vms_nod_lables.csv
