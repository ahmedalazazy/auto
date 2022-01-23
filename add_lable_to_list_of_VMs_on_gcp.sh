#!/bin/bash

echo "This Script for Automate add_lable_to_list_of_VMs_on_gcp"
echo "Please create file with name equal the name : 'file00.txt' "
echo "Please thid data in thadsame line for evrey vm on the file "
echo "VM NAME small chracters,VM ZONE,Lable Key,Lable Value,VM Project ID"

input="file00.txt"

while IFS=, read VMNAME ZONE KEY VA Project
do


  gcloud compute instances add-labels "$VMNAME" --labels="$KEY=$VA" --zone="$ZONE" --project="$Project"
  echo "$VMNAME,$ZONE,$KEYYYY,$Project-Done" >> add_lable_logs



done < "$input"
