#!/usr/bin/env bash

RED='\033[01;31m'
RESET='\033[0m'
GREEN='\033[01;32m'

clear
echo -e "$GREEN**********************************************************************************$RESET"
echo -e "  This Script for Automate Listing VM's from GCP not on Soaltanal by lable $RESET"
echo -e "                            Github: $GREEN ahmedalazazy"
echo -e "$GREEN*****************************************************************************$RESET"
echo " "
echo " "
echo ""
echo -e "                        \t   $RED Hi $USER $RESET"
echo ""
echo "Compute"

read -p "Please Type Project ID :" PROJECTT;
read -p "please enter Lable Key for the lable assind to VM's not in Soaltanal : " KKEY;
read -p "Please enter Lable value for the lable assind to VM's not in Soaltanal : " VVALUE;
gcloud config set project "$PROJECTT"
echo "NAME_INSTANCE,CPU,MEMGB,ZONE,STATUS,CREATIONTIME,INTERNAL_IP,EXTERNAL_IP,DISKS_GB" > ${PROJECTT}_Compute.csv
echo "$KKEY:$VVALUE"

for PAIR in $(gcloud compute instances list  --filter="labels.$KKEY:$VVALUE"  --format="csv[no-heading](name,zone.scope(zones),INTERNAL_IP,EXTERNAL_IP,STATUS,disks[].diskSizeGb,creationTimestamp,labels)"  --project=${PROJECTT} --sort-by=creationTimestamp)
do
# Parse result from above into instance and zone vars
IFS=, read INSTANCE ZONE INTERNAL EXTERNAL STATUS DISKS CREATIONTIME LABELS <<< ${PAIR}
# Get the machine type value only
MACHINE_TYPE=$(gcloud compute instances describe ${INSTANCE} --format="value(machineType.scope(machineTypes))" --zone="$ZONE"  --project=${PROJECTT} )
  # If it's custom-${vCPUs}-${RAM} we've sufficient info
if [[ ${MACHINE_TYPE}} == custom* ]]
  then
  IFS=- read CUSTOM CPU MEM <<< ${MACHINE_TYPE}
      
  MEMGB=0
  MEMGB=$((MEM/1024))

  printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s;\n" ${INSTANCE} ${CPU} ${MEMGB} ${ZONE} ${STATUS} ${CREATIONTIME} ${INTERNAL} ${EXTERNAL} ${DISKS} ${LABELS}
else
# Otherwise, we need to call `machine-types describe`
    CPU_MEMORY=$(gcloud compute machine-types describe ${MACHINE_TYPE} --format="csv[no-heading](guestCpus,memoryMb)" --zone="$ZONE"  --project=${PROJECTT} )
    IFS=, read CPU MEM <<< ${CPU_MEMORY}
      
    MEMGB=0
    MEMGB=$((MEM/1024))
    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s;\n" ${INSTANCE} ${CPU} ${MEMGB} ${ZONE} ${STATUS} ${CREATIONTIME} ${INTERNAL} ${EXTERNAL} ${DISKS} ${LABELS}
fi
done >> ${PROJECTT}_Compute.csv
