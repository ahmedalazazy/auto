#!/bin/bash

# Read user inputs
read -p "Enter your GCP project name: " project_name
read -p "Enter the VM instance name: " vm_name

# Prompt user to choose a Subnet
echo "Select Subnet:"
echo "1- default"
echo "2- Enter custom subnetwork"
read -p "Enter your choice: " subnetwork_choice

case $subnetwork_choice in
   1)
      subnetwork="default"
      ;;
   2)
      read -p "Enter the VPC subnetwork: " subnetwork
      ;;
   *)
      echo "Invalid subnetwork choice. Exiting."
      exit 1
      ;;
esac

# Prompt user to choose an OS image
echo "1- Red Hat 7"
echo "2- Red Hat 8"
echo "3- Rocky Linux"
echo "4- * (Handle wildcard as needed)"
read -p "Enter your choice: " os_choice

case $os_choice in
   1)
      image_family="rhel-7"
      image_project="rhel-cloud"
      ;;
   2)
      image_family="rhel-8"
      image_project="rhel-cloud"
      ;;
   3)
      image_family="rocky-linux-8"
      image_project="rocky-linux-cloud"
      ;;
   4)
      # Set default values or handle wildcard as needed
      image_family="rhel-8"
      image_project="rhel-cloud"
      ;;
   *)
      echo "Invalid OS image choice. Exiting."
      exit 1
      ;;
esac

# Prompt user to choose a zone
echo "1- us-central1-a"
echo "2- europe-west1-b"
echo "3- me-central2"
read -p "Enter the zone number: " zone_choice

case $zone_choice in
   1)
      zone="us-central1-a"
      ;;
   2)
      zone="europe-west1-b"
      ;;
   3)
      zone="me-central2"
      ;;
   *)
      echo "Invalid zone choice. Exiting."
      exit 1
      ;;
esac

# Define array of machine types and choose a machine type
echo "1- n1-standard-2"
echo "2- n1-standard-4"
echo "3- n1-standard-8"
read -p "Select machine type: " machine_type_choice

case $machine_type_choice in
   1)
      chosen_machine_type="n1-standard-2"
      ;;
   2)
      chosen_machine_type="n1-standard-4"
      ;;
   3)
      chosen_machine_type="n1-standard-8"
      ;;
   *)
      echo "Invalid machine type. Exiting."
      exit 1
      ;;
esac

# Prompt user to choose a disk size
echo "1- 50GB"
echo "2- 100GB"
echo "3- 200GB"
read -p "Select a disk size: " disk_size_choice

case $disk_size_choice in
   1)
      chosen_disk_size="50GB"
      ;;
   2)
      chosen_disk_size="100GB"
      ;;
   3)
      chosen_disk_size="200GB"
      ;;
   *)
      echo "Invalid disk size. Exiting."
      exit 1
      ;;
esac

# Create the VM instance
gcloud compute instances create "${vm_name}" \
  --project="${project_name}" --image-family="${image_family}" --image-project="${image_project}" \
  --machine-type="${chosen_machine_type}" --zone="${zone}" --subnet="${subnetwork}" --min-cpu-platform="Intel Haswell" \
  --boot-disk-size="${chosen_disk_size}" --boot-disk-type="pd-standard" --enable-nested-virtualization

echo "VM instance '${vm_name}' has been created."
