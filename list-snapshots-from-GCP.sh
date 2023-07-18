#!/bin/bash

# Prompt the user to enter the project ID
read -p "Enter the project ID: " PROJECT_ID

# Use the PROJECT_ID variable in the gcloud command
gcloud compute snapshots list \
  --format="csv(name,creation_timestamp,disk_size_gb,storage_bytes,storage_locations,SRC_DISK.basename(),status)" \
  --project=${PROJECT_ID} > ${PROJECT_ID}_snapshots.csv
