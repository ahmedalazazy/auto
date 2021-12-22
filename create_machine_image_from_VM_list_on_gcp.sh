#!/usr/bin/env bash"

RED='\033[01;31m'
RESET='\033[0m'
GREEN='\033[01;32m'

clear
echo -e "                        \t   $RED Hi $USER $RESET"
#sleep 2
echo -e "$GREEN**********************************************************************************$RESET"
#sleep 1
echo -e "  				This Script for Automate to create machine-images for an instance On GCP **$RESET"              
#sleep 3
echo -e "$GREEN*****************************Github: ahmedalazazy*********************************$RESET"
#sleep 2
echo -e " \t $RED Please $USER add VMs and zone to file and make name of the file=file00.txt     $RESET"
#sleep 3
echo -e " \t $RED Please $USER and make syntax NAME and zone in this file like this : ServerNAME,SERVERZONE $RESET"
#sleep 2
echo -e "$GREEN**********************************************************************************$RESET"
echo ""
echo -e "                        \t   $RED Hi $USER $RESET"
echo ""
read -p "Please enter project you need to create machine-images under it : " PROJECTT;
gcloud config set project "$PROJECTT"
echo "Project set to "$PROJECTT""
while IFS=, read NAME ZONE; do
	gcloud config set compute/zone "$ZONE"
	gcloud beta compute machine-images create "${NAME}" --source-instance="$NAME"  --project="$PROJECTT"
done <<< $( cat file00.txt)
