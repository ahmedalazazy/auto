#!/bin/bash

RED='\033[01;31m'
RESET='\033[0m'
GREEN='\033[01;32m'

clear
echo -e "$GREEN****************************************************************************************$RESET"
echo -e "                \t  \t   This Script for Automate restore disks from SNAPSHOT $RESET                                 "
echo -e "$GREEN****************************************************************************************$RESET"
echo " "
read -p "Please Enter The Instance NAME : " INSTANCE_NAME;
read -p "Please Enter Instance DISK NAME need to restore: " ORGDISK_NAME;
read -p "Please Enter SNAPSHOT DISK NAME : " SNAPSHOT_DISK_NAME;
read -p "Please Enter Disk Type : " DISKTYPES;
read -p "Please Enter Disk zone : " ZONE;
read -p "Enter 1 for boot disk and 2 for nonboot disk :" BOOTTT ;

NEW_DISK="$ORGDISK_NAME-rfs"

case $BOOTTT in
  1)
	echo "..."
	gcloud beta compute instances detach-disk "$INSTANCE_NAME" --disk "$ORGDISK_NAME" &&	gcloud compute disks create "$NEW_DISK" --source-snapshot "$SNAPSHOT_DISK_NAME" --zone "$ZONE" --type="https://www.googleapis.com/compute/v1/projects/aig-sap-dev/zones/$ZONE/diskTypes/$DISKTYPES"
	gcloud beta compute instances attach-disk "$INSTANCE_NAME" --disk "$NEW_DISK" --zone "$ZONE" --boot
	    ;;
  2)
	echo "..."
	gcloud beta compute instances detach-disk "$INSTANCE_NAME" --disk "$ORGDISK_NAME" && gcloud compute disks create "$NEW_DISK" --source-snapshot "$SNAPSHOT_DISK_NAME" --zone "$ZONE" --type="https://www.googleapis.com/compute/v1/projects/aig-sap-dev/zones/$ZONE/diskTypes/$DISKTYPES"
	gcloud beta compute instances attach-disk "$INSTANCE_NAME" --disk "$NEW_DISK" --zone "$ZONE"
	    ;;
  *)
    echo -e "$GREEN******************************************************************************$RESET"
    echo -n                 "$RED unknown what you need to do  $RESET"
    echo -e "$GREEN******************************************************************************$RESET"
    ;;

esac
