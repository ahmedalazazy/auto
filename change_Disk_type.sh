#!/usr/bin/bash
############################################################################################################################## 
#this code by Ahmed Alazazy Github @ahmedalazazy
#you can using this script to change disk type,this code is opensourse  
##1-stop vm
#2-take snapshot from all disks but not take os disk
#3-recreate disks in vm with the samy spase disk but shange disk type to stander disks 
#4-detatch old disks and attach new disks
#5-start vm 
#6-rerun script to tack new vm name ro repet procec#
#if you neeed this script asking you what if zone you need after and comment the below line 
#############################################################################################################################

read -p "Please type zone : " ZONE;
ZONE="europe-west1-b"
read -p "Please Enter INSTANS NAME :" INSTANCE_NAME;
read -p "Please Enter USIDG INSTANS DISK NAME : " ORGDISK_NAME;
read -p "Please Enter USIDG Snapshoot SCHEDULE NAME to ad in new disk : " SCHEDULE_NAME;
#type project id you need script work in him
PROJECT_ID="";
#Tyepe Desk value you need to change vm to 
DISKTYPES="pd-standard";
#DIsksType
#pd-standard 
#pd-balanced 
#pd-ssd
MACHINE_IMAGE_NAME="$INSTANCE_NAME-vm-image-before-change-type"
MASHINE_IMAGE_STATUS=$(gcloud beta compute machine-images list --filter=name:"$MACHINE_IMAGE_NAME" --format="value(status)")
DISK_NAME="$ORGDISK_NAME-snapshot";
NEW_DISK="$ORGDISK_NAME-newType";
VMSTATUS=$(gcloud compute instances list  --filter=name:"$INSTANCE_NAME" --format="value(status)");
if [[ $VMSTATUS -eq "RUNNING" ]]; then
	gcloud compute instances stop $INSTANCE_NAME --zone "$ZONE";
	echo "vm in stoping process";
else
	echo "This virtual machine is already powered OFF"
fi
############################################################################################################################################################
if [[ $MASHINE_IMAGE_STATUS -ne "READY" ]]; then
	gcloud beta compute machine-images create $MACHINE_IMAGE_NAME --source-instance "$INSTANCE_NAME" ;
else
	echo "MACHINE_IMAGE_NAME is already created";
fi
####################################################################################
gcloud compute disks snapshot "$ORGDISK_NAME" --zone "$ZONE" --snapshot-names="$DISK_NAME";
echo "tacke snapshot in process";
sleep 90 #disk creating will take few mints and nest steps need this to finsh after starting
#####################################################################################
#if you need to change disk type you can edit --type="name of disk type" or make it my var
gcloud compute disks create "$NEW_DISK" --source-snapshot "$DISK_NAME" --type="https://www.googleapis.com/compute/v1/projects/$PROJECT_ID/zones/$ZONE/diskTypes/$DISKTYPES" --resource-policies "SCHEDULE_NAME"  --zone "$ZONE";
echo "new DISK in creating process";
sleep 10 
#####################################################################################
gcloud beta compute instances detach-disk "$INSTANCE_NAME" --disk "$ORGDISK_NAME" --zone "$ZONE";
echo "detaching old disk in process"
#####################################################################################
#if thes disk is a boot vm disk please add --boot in the below line 
gcloud beta compute instances attach-disk "$INSTANCE_NAME" --disk "$NEW_DISK" --zone "$ZONE";
echo "attach new disk in process";
###################################################################################################################################################################
read -p "to keep vm stoped type 0 to start vm type 1  : " STOPSTART;
#this if to ask you if you not need to take more actions in thes vm start it if you stell need more actions keep it stoped
if [[ $STOPSTART -eq "1" ]]; then
	gcloud compute instances start $INSTANCE_NAME;
	echo "vm started";
else
	echo "vm still stoped "
fi;
#########################################################################################################################################################################
