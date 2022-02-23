#!/bin/bash

gcloud compute disks list --format="table(NAME,LOCATION)" | sed '1d' > disks.list
while read -r NAME ZONE
do
	gcloud compute disks describe $NAME --zone $ZONE |grep -q daily-snapshots || gcloud compute disks describe $NAME --zone $ZONE |grep -q hourly-snapshots || gcloud compute disks describe $NAME --zone $ZONE |grep -q weekly-snapshots
	if [ "$?" != "0" ]; then
		gcloud compute disks add-resource-policies $NAME --resource-policies daily-snapshots --zone $ZONE

	fi 
done < disks.list

rm -f disks.list