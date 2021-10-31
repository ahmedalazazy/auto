#!/usr/bin/bash

gcloud beta compute machine-images list  --filter="creationTimestamp<$(date -d "-60 days" "+%Y-%m-%d")" --uri | while read SNAPSHOT_URI;
do
   gcloud beta compute machine-images delete $SNAPSHOT_URI  --quiet
done
