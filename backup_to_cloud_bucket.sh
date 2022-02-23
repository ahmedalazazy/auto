#!/bin/bash
##
#gcloud auth activate-service-account SERVICE_ACCOUNT@DOMAIN.COM --key-file=/path/key.json \
#--project=PROJECT_ID
#
#1- gloud auth 2- add the neded folder path and cloud bucket path

PATHHH="/home/azazy/test/*"

DATEE="$(date '+%F_%I%M_%Z')"

if [ -n "$(ls ${PATHHH} 2>/dev/null)" ]
then

   gsutil cp ${PATHHH} gs://test_NAME/${DATEE} && gsutil cp -r  ${PATHHH} gs://test_NAME/${DATEE}

else
 
   gsutil cp ${PATHHH} gs://test_NAME/${DATEE}

fi

if [ "$?" = "0" ]; then
 
 rm -rf $PATHHH
 
fi        