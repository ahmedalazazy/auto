#!/bin/bash
RED='\033[01;31m'
RESET='\033[0m'
GREEN='\033[01;35m'

clear
echo -e "$GREEN*************************************$RESET*$RED***********************************************$RESET"
echo -e "\t \t This Script for Copy VM to anther project $RESET"
echo -e "                            Github: $GREEN ahmedalazazy"
echo -e "$GREEN*************************************$RESET*$RED***********************************************$RESET"

read -p "Enter the Original Server Name :  " ORIGINAL_SERVER_NAME;
echo " "
read -p "Enter the Original Project ID : " ORIGINAL_PROJECT_ID;
echo " "
read -p "Enter the NEW Project ID :  " NEW_PROJECT_ID;
echo " "
echo -e "Need new name for this VM on new project or use the original name ?"
echo " "
echo "For Original name Enter 1 "
echo " "
echo "For New name Enter 2 "
echo " "
read VMNAME;

if [ "$VMNAME" -eq "1" ]; then
    SERVERNAME="${ORIGINAL_SERVER_NAME}"
else
    read -p "Enter the New Server Name to use on new project :  " SERVERNAME;
fi

read -p "Enter the NEW ZONE : " NEW_ZONE;
echo ""
read -p "If you have Machine-Image created Enter 1 or to create New type 2 : " MACHINE_IMAGE;

if [ "$MACHINE_IMAGE" -eq "1" ]; then

   read -p "Enter the Machine image Name : " CREATED_MACHIN_IMAGE;

else

    read -p "Enter the New Machine image Name to create :  " CREATED_MACHIN_IMAGE;
  	gcloud beta compute machine-images create "${CREATED_MACHIN_IMAGE}" --source-instance="${ORIGINAL_SERVER_NAME}" --source-instance-zone="${NEW_ZONE}" --project="${ORIGINAL_PROJECT_ID}"

fi


read -p "Enter the NEW subnet name on new project :  " NEW_SUBNETWORK;
echo " "
echo "Enter the NEW or same internal IP on the new project "
echo " "
read -p "Please Make sure please the ip valid on new subnet :   " NEW_INTERNAL_IP;

read -p "Please Type the Compute Engine default service account on NEW PROJECT : " SERVICE_ACCOUNT;
 
echo "To create this VM on Sole-tenancy Please type 1 else type 2 "
read -p "Please macke sure if you create on Sole-tenancy chose the same Sole-tenancy machine type :  " SOLE_TANE_OR_NO;
echo " "
echo " "
read -p "Please Type the New MACHINE_TYPE on NEW PROJECT :  " MACHINE_TYPE;

if [ "$SOLE_TANE_OR_NO" -eq "1" ]; then

read -p "Please Type Affinity Lable for Sole-tenancy Group on NEW PROJECT :  " AFFINITY_LABLE;
gcloud beta compute instances create "${SERVERNAME}" --project="${NEW_PROJECT_ID}" --zone="${NEW_ZONE}" --source-machine-image="projects/${ORIGINAL_PROJECT_ID}/global/machineImages/${CREATED_MACHIN_IMAGE}" --network-interface=private-network-ip="${NEW_INTERNAL_IP}",subnet="${NEW_SUBNETWORK}",no-address --service-account="${SERVICE_ACCOUNT}" --maintenance-policy="MIGRATE" --machine-type="${MACHINE_TYPE}" --node-group="${AFFINITY_LABLE}" --restart-on-failure

else

gcloud beta compute instances create "${SERVERNAME}" --project="${NEW_PROJECT_ID}" --zone="${NEW_ZONE}" --source-machine-image="projects/${ORIGINAL_PROJECT_ID}/global/machineImages/${CREATED_MACHIN_IMAGE}" --network-interface=private-network-ip="${NEW_INTERNAL_IP}",subnet="${NEW_SUBNETWORK}",no-address --service-account="${SERVICE_ACCOUNT}" --maintenance-policy="MIGRATE" --machine-type="${MACHINE_TYPE}" --restart-on-failure

fi

read -p "Enter 1 to stop the new created VM or 2 to finish process :  " STATESFORVM;

if [ "$STATESFORVM" -eq "1" ]; then

    gcloud compute instances stop "${SERVERNAME}" --project="${NEW_PROJECT_ID}" --zone="${NEW_ZONE}"

fi
