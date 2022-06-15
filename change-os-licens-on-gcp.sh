#!/bin/bash

RED='\033[01;31m'
RESET='\033[0m'
GREEN='\033[01;32m'

clear
echo -e "$GREEN*************************************$RESET*$RED***********************************************$RESET"
echo -e " This Script for Automate change VM licince for GCP instance and move this vm to Sole-tenancy $RESET"
echo -e "                            Github: $GREEN ahmedalazazy $RESET"
echo -e "$GREEN*************************************$RESET*$RED***********************************************$RESET"
echo "$GREEN**Macke sure you have Sole-tenancy and cloud bucket created**$RESET"

echo " "
echo " "

read -p "ENTER PROJECT ID : " WORKINGPROJECT;
echo " "
read -p "Enter Boot Disk Name: " OLD_BOOT_DISK_NAME;
echo " "

read -p "Enter VM Name: " VM_NAME;
echo " "

echo "example gs://for-change-licence"

echo "without / on end link"

read -p "Enter gsutil url for Cloud Bucket : " CLOUDBUCKETURL;
echo " "

read -p "Enter Affinite Lable for Sole-tenancy Group : " NODEGROUPNAME;
echo " "

NEW_BOOT_DISK_NAME="$OLD_BOOT_DISK_NAME-byol"

OLDBOOT_DISK_LICENSE=$(gcloud beta compute disks describe "${OLD_BOOT_DISK_NAME}" --project="${WORKINGPROJECT}" --format="value(licenses.scope(licenses))")

APPENDED_IMAGE_FROM_OLD_DISK="$OLD_BOOT_DISK_NAME-appended"

IMPORTED_IMAGE_FROM_VMDK="$OLD_BOOT_DISK_NAME-byol"

VM_ZONE=$(gcloud compute instances list --filter="name=($VM_NAME)" --project="$WORKINGPROJECT" --format="value(zone.scope(zone))")

OLD_DISK_ZONE=$(gcloud beta compute disks describe "$OLD_BOOT_DISK_NAME" --project="$WORKINGPROJECT" --format="value(zone.scope(zone))")

OLD_DISK_TYPE=$(gcloud beta compute disks describe "$OLD_BOOT_DISK_NAME" --project="$WORKINGPROJECT" --format="value(type)")

DESTINATION_VMDK_URI="$CLOUDBUCKETURL/$APPENDED_IMAGE_FROM_OLD_DISK.vhdx"

echo " "
echo "OLDBOOT_DISK_LICENSE=($OLDBOOT_DISK_LICENSE)"
echo " "

echo "1- windows server DC 2019"
echo "2- windows server DC 2016"
echo "3- windows server DC 2012"
echo "4- For another OS"

echo " "
echo " "

read -p "Choose os version  :  " OSV;

case $OSV in 
    1)
        LICENSE_URIS="https://www.googleapis.com/compute/beta/projects/windows-cloud/global/licenses/windows-server-2019-byol"
        OS_NAME="windows-2019-byol"
        ;;
    2)
        LICENSE_URIS="https://www.googleapis.com/compute/beta/projects/windows-cloud/global/licenses/windows-server-2016-byol"
        OS_NAME="windows-2016-byol"
        ;;
    3)
        LICENSE_URIS="https://www.googleapis.com/compute/beta/projects/windows-cloud/global/licenses/windows-server-2012-byol"
        OS_NAME="windows-2012-byol"
        ;;
    4)
        read -p "Please type LICENSE_URIS you need to use : " LICENSE_URIS;
        read -p "Please type OS_NAME you need to use : " OS_NAME;
        ;;
    *)
        echo "some fucking error and script cant understand error to handle it" 
        ;;
esac

echo "step 1 from 10"

gcloud beta compute disks update "${OLD_BOOT_DISK_NAME}" --update-user-licenses="${LICENSE_URIS}" --project="${WORKINGPROJECT}"
echo " "

echo "step 2 from 10"
gcloud compute images create "${APPENDED_IMAGE_FROM_OLD_DISK}" --project="${WORKINGPROJECT}" --source-disk="${OLD_BOOT_DISK_NAME}"  --source-disk-zone="${OLD_DISK_ZONE}"
echo " "

echo "step 3 from 10 export disk to vmdk"
gcloud compute images export --destination-uri="${DESTINATION_VMDK_URI}" --image="${APPENDED_IMAGE_FROM_OLD_DISK}" --project="${WORKINGPROJECT}" --timeout="24h" --export-format=vhdx

case $? in
    0)
        echo "export success god job Azazy :)" 
        sleep 5
        ;;
    1)

        echo "export failed"
        echo "step run to traing again"
        gcloud compute images export --destination-uri="${DESTINATION_VMDK_URI}" --image="${APPENDED_IMAGE_FROM_OLD_DISK}" --project="${WORKINGPROJECT}" --timeout="24h" --export-format=vhdx
        sleep 5
        ;;
    *)
        echo "export step facing some fucking error and script cant understand error to handle it"   
        sleep 5
        ;;  
esac  



echo "step 4  from 10 import image"  
gcloud compute images import "${IMPORTED_IMAGE_FROM_VMDK}" --source-file="${DESTINATION_VMDK_URI}" --guest-environment --os="${OS_NAME}"  --project="${WORKINGPROJECT}" --timeout="24h"

case $? in
    0)
        echo "import success god job Azazy :)"  
        sleep 5
        ;;
    1)

        echo "import failed"
        echo "step run to traing import again"
        gcloud compute images import "${IMPORTED_IMAGE_FROM_VMDK}" --source-file="${DESTINATION_VMDK_URI}" --guest-environment --os="${OS_NAME}"  --project="${WORKINGPROJECT}" --timeout="24h"
        sleep 5
        ;;
    *)
        echo "import step facing some fucking error and script cant understand error to handle it"   
        sleep 5
        ;;  
esac  

echo "step 5 from 10"
gcloud compute disks create "${NEW_BOOT_DISK_NAME}" --image="${IMPORTED_IMAGE_FROM_VMDK}"  --type="${OLD_DISK_TYPE}"
echo " "

echo "step 6 from 10"
gcloud beta compute instances detach-disk "${VM_NAME}" --disk="${OLD_BOOT_DISK_NAME}" --project="${WORKINGPROJECT}"
echo " "

echo "step 7 from 10"
gcloud beta compute instances attach-disk "${VM_NAME}" --disk="${NEW_BOOT_DISK_NAME}" --boot --zone="${VM_ZONE}" --project="${WORKINGPROJECT}"
echo " "

echo "step 8 from 10"
gcloud compute instances add-metadata "${VM_NAME}" --metadata=license_url="${LICENSE_URIS}" --zone="${VM_ZONE}" --project="${WORKINGPROJECT}"
echo " "

echo "step 9 from 10"
gcloud compute instances set-scheduling "${VM_NAME}" --node-group="${NODEGROUPNAME}" --maintenance-policy="MIGRATE" --restart-on-failure --zone="${VM_ZONE}" --project="${WORKINGPROJECT}"
echo " "

echo "step 10 from 10"
gcloud compute instances start "${VM_NAME}" --zone="${VM_ZONE}" --project="${WORKINGPROJECT}"
echo " "
