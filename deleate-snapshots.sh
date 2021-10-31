#!/usr/bin/bash
gcloud compute snapshots list --filter="creationTimestamp<$(date -d "-60 days" "+%Y-%m-%d")" --uri | while read SNAPSHOT_URI;
do
   gcloud compute snapshots delete $SNAPSHOT_URI  --quiet
done
