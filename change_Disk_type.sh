#!/usr/bin/bash
#this code by Ahmed Alazazy Github @ahmedalazazy
#you can using this script to change disk type,this code is opensourse  
##1-stop vm
#2-take snapshot from all disks but not take os disk
#3-recreate disks in vm with the samy spase disk but shange disk type to stander disks 
#4-detatch old disks and attach new disks
#5-start vm 
#6-rerun script to tack new vm name ro repet procec#
ZONE="europe-west1-b"
read -p "Please Enter INSTANS NAME :" INSTANCE_NAME;
read -p "Please Enter USIDG INSTANS DISK NAME : " ORGDISK_NAME;
DISK_NAME="$ORGDISK_NAME-snapshot";
NEW_DISK="$ORGDISK_NAME-newType";
gcloud compute instances stop $INSTANCE_NAME --zone "$ZONE";
echo "vm in stoping process";
gcloud compute disks snapshot "$ORGDISK_NAME" --zone=us-central1-a --snapshot-names="$DISK_NAME";
echo "tacke snapshot in process";
#if you need to change disk type you can edit --type="name of disk type" or make it my var
gcloud compute disks create "$NEW_DISK" --source-snapshot "$DISK_NAME" --type="pd-standard" --zone "$ZONE";
echo "new DISK in creating process";
gcloud beta compute instances detach-disk "$INSTANCE_NAME" --disk "$ORGDISK_NAME" --zone "$ZONE";
echo "detaching old disk in process"
#if thes disk is a boot vm disk please add --boot in the below line 
gcloud beta compute instances attach-disk "$INSTANCE_NAME" --disk "$NEW_DISK" --zone "$ZONE";
echo "attach new disk in process";
read -p "to keep vm stoped type 0 to start vm type 1  : " STOPSTART;
#this if to ask you if you not need to take more actions in thes vm start it if you stell need more actions keep it stoped
if [[ $STOPSTART -eq "1" ]]; then
	gcloud compute instances start $INSTANCE_NAME;
	echo "vm started";
else
	echo "vm still stoped "
fi;
