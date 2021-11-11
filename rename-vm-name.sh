#!/usr/bin/env bash

RED='\033[01;31m'
RESET='\033[0m'
GREEN='\033[01;32m'

clear
echo -e "$GREEN****************************************************************************************$RESET"
echo -e "                            Github: $GREEN ahmedalazazy"
echo -e "$GREEN****************************************************************************************$RESET"
echo " "
echo " "
echo ""
echo -e "                        \t   $RED Hi $USER $RESET"
echo " "

echo "Using this Script to rename Instans Name on GCP";
echo "This process will stop INSTANS";
read -p "Please Enter Instans Name" CURRENT_NAME;
read -p "Please Enter New Instans Name" NEW_NAME;
read -p "Please Enter Instans ZONE" ZONE;
gcloud compute instances stop "$CURRENT_NAME" --zone "$ZONE"
echo "VM In Stoping process"
gcloud beta compute instances set-name "$CURRENT_NAME" --zone "$ZONE" --new-name="$NEW_NAME"
echo "VM In rename process"
gcloud compute instances start "$NEW_NAME" --zone="$ZONE"
echo "VM started with New Name $NEW_NAME"
