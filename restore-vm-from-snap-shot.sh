#!/bin/bash
read -p "Please Enter INSTANS NAME :" INSTANCE_NAME;
read -p "Please Enter USIDG INSTANS DISK NAME : " ORGDISK_NAME;
read -p "Please Enter SNAPSHOT DISK NAME : " SNAPSHOT_DISK_NAME;
read -p "Please Enter Zone NAME : " ZONE;
NEW_DISK="$ORGDISK_NAME-restored-from-snapshot"
gcloud beta compute instances detach-disk "$INSTANCE_NAME" --disk "$ORGDISK_NAME"
gcloud compute disks create "$NEW_DISK" --source-snapshot "$SNAPSHOT_DISK_NAME" --zone "$ZONE"
gcloud beta compute instances attach-disk "$INSTANCE_NAME" --disk "$NEW_DISK" --boot --zone "$ZONE"