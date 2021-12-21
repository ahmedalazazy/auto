#!/usr/bin/env bash
while IFS= read -r PROJECT; do
RED='\033[01;31m'
RESET='\033[0m'
GREEN='\033[01;32m'

clear
echo -e "$GREEN**********************************************************************************$RESET"
echo -e "  This Script for Automate Listing resourses from GCP for minie projects and extract to csv files $RESET"
echo -e "                 You must make sure add projects ID in file00.txt  before running"
echo -e "                            Github: $GREEN ahmedalazazy"
echo -e "$GREEN*****************************************************************************$RESET"
echo " "
echo " "


echo ""
echo -e "                 \t       \t   $RED Hi $USER $RESET"
echo ""

gcloud config set project "${PROJECT}"
mkdir ${PROJECT}
########################################################################################################################################################################################################################################
echo "1-Services"
gcloud services list --project=${PROJECT} > ${PROJECT}/${PROJECT}_all_services.csv
########################################################################################################################################################################################################################################
echo "2-Disks"
gcloud compute disks list --format="csv(NAME,LOCATION,LOCATION_SCOPE,SIZE_GB,TYPE,STATUS,sourceImage,creationTimestamp,users,lastAttachTimestamp,physicalBlockSizeBytes,zone,resourcePolicies)" --project=${PROJECT} > ${PROJECT}/${PROJECT}_all_disks.csv
########################################################################################################################################################################################################################################
echo "3-Service Accounts"
for ACCOUNT in $(gcloud iam service-accounts list --project=${PROJECT} --format="value(email)")
do
gcloud iam service-accounts keys list --iam-account=${ACCOUNT} --project=${PROJECT} | tr -s " " "," > ${PROJECT}/${PROJECT}_accounts.csv
done
echo "4-Compute"
    echo "NAME_INSTANCE,CPU,MEMGB,ZONE,STATUS,CREATIONTIME,INTERNAL_IP,EXTERNAL_IP,DISKS_GB"> ${PROJECT}/${PROJECT}_Compute.csv
    for PAIR in $(gcloud compute instances list --format="csv[no-heading](name,zone.scope(zones),INTERNAL_IP,EXTERNAL_IP,STATUS,disks[].diskSizeGb,creationTimestamp,labels)" --project=${PROJECT} --sort-by=creationTimestamp)
    do
    # Parse result from above into instance and zone vars
    IFS=, read INSTANCE ZONE INTERNAL EXTERNAL STATUS DISKS CREATIONTIME LABELS <<< ${PAIR}
    # Get the machine type value only
    MACHINE_TYPE=$(gcloud compute instances describe ${INSTANCE} --format="value(machineType.scope(machineTypes))" --zone="$ZONE"  --project=${PROJECT} )
      # If it's custom-${vCPUs}-${RAM} we've sufficient info
    if [[ ${MACHINE_TYPE}} == custom* ]]
	  then
      IFS=- read CUSTOM CPU MEM <<< ${MACHINE_TYPE}
	      
	  MEMGB=0
	  MEMGB=$((MEM/1024))

	  printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s;\n" ${INSTANCE} ${CPU} ${MEMGB} ${ZONE} ${STATUS} ${CREATIONTIME} ${INTERNAL} ${EXTERNAL} ${DISKS} ${LABELS}
    else
    # Otherwise, we need to call `machine-types describe`
	    CPU_MEMORY=$(gcloud compute machine-types describe ${MACHINE_TYPE} --format="csv[no-heading](guestCpus,memoryMb)" --zone="$ZONE"  --project=${PROJECT} )
	    IFS=, read CPU MEM <<< ${CPU_MEMORY}
	      
	    MEMGB=0
	    MEMGB=$((MEM/1024))
	    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s;\n" ${INSTANCE} ${CPU} ${MEMGB} ${ZONE} ${STATUS} ${CREATIONTIME} ${INTERNAL} ${EXTERNAL} ${DISKS} ${LABELS}
	fi
    done >> ${PROJECT}/${PROJECT}_Compute.csv

########################################################################################################################################################################################################################################
echo "5-networks_subnets"
gcloud compute networks subnets list --sort-by=NETWORK --project=${PROJECT}  --format="csv(NAME,REGION,NETWORK,RANGE,STACK_TYPE,IPV6_ACCESS_TYPE,IPV6_CIDR_RANGE,EXTERNAL_IPV6_CIDR_RANGE)" > ${PROJECT}/${PROJECT}_networks_subnets.csv
########################################################################################################################################################################################################################################
echo "6-networks_routes"
gcloud compute routes list --sort-by=NETWORK --project=${PROJECT} --format="csv(NAME,NETWORK,DEST_RANGE,NEXT_HOP,PRIORITY)" >> ${PROJECT}/${PROJECT}_networks_routes.csv
########################################################################################################################################################################################################################################
echo "7-networks_rules"
gcloud compute firewall-rules list --sort-by=NETWORK --project=${PROJECT} --format="csv(NAME,NETWORK,DIRECTION,ALLOW,DENY,DISABLED,PRIORITY,selfLink.basename(),sourceRanges,targetTags,IPProtocol,ports,creationTimestamp)" > ${PROJECT}/${PROJECT}_firewall_rules.csv
########################################################################################################################################################################################################################################
echo "8-networks_forwarding-rules"
gcloud compute forwarding-rules list --project=${PROJECT} --format="csv(NAME,REGION,IP_ADDRESS,IP_PROTOCOL,TARGET)" > ${PROJECT}/${PROJECT}_forwarding-rules.csv

########################################################################################################################################################################################################################################
echo "9-services list"
gcloud services list --available --format="csv(NAME,TITLE)" --project=${PROJECT} > ${PROJECT}/${PROJECT}_services_list.csv
########################################################################################################################################################################################################################################
echo "10-machine-images list"
gcloud beta compute machine-images list --format="csv(NAME,STATUS,creation_timestamp)" --project=${PROJECT} > ${PROJECT}/${PROJECT}_machine_images.csv
########################################################################################################################################################################################################################################
DATTT=$(date -d "-60 days" '+%Y-%m-%d')
echo "11-machine-images created before 60day list"
gcloud beta compute machine-images list --format="csv(NAME,STATUS,creation_timestamp)"  --filter="creationTimestamp<$DATTT"  --project=${PROJECT} > ${PROJECT}/${PROJECT}__createdbefore60Day.csv
########################################################################################################################################################################################################################################
echo "12-snapshots list"
gcloud compute snapshots list  --format="csv(name,creation_timestamp,disk_size_gb,storage_bytes,storage_locations,SRC_DISK.basename(),status)" --project=${PROJECT} > ${PROJECT}/${PROJECT}_snapshots.csv
########################################################################################################################################################################################################################################
echo "13-snapshots created before 60day list"
DATTT=$(date -d "-60 days" '+%Y-%m-%d')
gcloud compute snapshots list  --format="csv(name,creation_timestamp,disk_size_gb,storage_bytes,storage_locations,SRC_DISK.basename(),status)" --filter="creationTimestamp<$DATTT" --project=${PROJECT} > ${PROJECT}/${PROJECT}_snapshots_createdbefore60Day.csv
########################################################################################################################################################################################################################################
echo "14-vpn-tunnels"
gcloud compute vpn-tunnels list --project=${PROJECT} --format="csv(NAME,creationTimestamp,detailedStatus,REGION,GATEWAY,PEER_ADDRESS,localTrafficSelector,remoteTrafficSelector,status,targetVpnGateway)" > ${PROJECT}/${PROJECT}_vpn_tunnels.csv
########################################################################################################################################################################################################################################

done <<< $(cat file00.txt )
