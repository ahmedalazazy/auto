#!/bin/bash

read -p "Enter the project ID: " PROJECT_ID

# List Cloud Run services
services=$(gcloud run services list --platform=managed --project=${PROJECT_ID} --format="value(URL)")

# Define the roles
CLOUD_RUN_ROLE="roles/run.admin"
CLOUD_SQL_CLIENT_ROLE="roles/cloudsql.client"
CLOUD_SQL_INSTANCE_USER_ROLE="roles/cloudsql.instanceUser"
CLOUD_SQL_SERVICE_AGENT_ROLE="roles/cloudsql.serviceAgent"
STORAGE_OBJECT_ADMIN_ROLE="roles/storage.admin"
STORAGE_OBJECT_CREATOR_ROLE="roles/storage.objectCreator"
STORAGE_OBJECT_VIEWER_ROLE="roles/storage.objectViewer"
MONITORING_METRIC_WRITER_ROLE="roles/monitoring.metricWriter"
LOGS_WRITER_ROLE="roles/logging.logWriter"
PUBSUB_ADMIN_ROLE="roles/pubsub.admin"

# Loop through each service
for service_url in $services; do
  # Extract the region from the service URL
  REGION=$(echo $service_url | awk -F/ '{print $4}')

  # Extract the service name from the URL
  SERVICE_NAME=$(echo $service_url | awk -F/ '{print $NF}')

  # Create a truncated service account name
  # Adjust the length as needed, ensuring it is between 6 and 30 characters
  service_account="${SERVICE_NAME:0:20}-sa"
  gcloud iam service-accounts create ${service_account} --display-name "${service} Service Account" --project=${PROJECT_ID}

  # Grant Cloud Run permissions
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${service_account}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=${CLOUD_RUN_ROLE} --project=${PROJECT_ID}

  # Grant Cloud SQL Client permissions
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${service_account}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=${CLOUD_SQL_CLIENT_ROLE} --project=${PROJECT_ID}

  # Grant Cloud SQL Instance User permissions
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${service_account}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=${CLOUD_SQL_INSTANCE_USER_ROLE} --project=${PROJECT_ID}

  # Grant Cloud SQL Service Agent permissions
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${service_account}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=${CLOUD_SQL_SERVICE_AGENT_ROLE} --project=${PROJECT_ID}

  # Grant Storage permissions
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${service_account}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=${STORAGE_OBJECT_ADMIN_ROLE} --project=${PROJECT_ID}

  # Grant Storage permissions
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${service_account}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=${STORAGE_OBJECT_CREATOR_ROLE} --project=${PROJECT_ID}


  # Grant Storage permissions
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${service_account}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=${STORAGE_OBJECT_VIEWER_ROLE} --project=${PROJECT_ID}

  # Grant Monitoring permissions
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${service_account}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=${MONITORING_METRIC_WRITER_ROLE} --project=${PROJECT_ID}

  # Grant Logging permissions
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${service_account}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=${LOGS_WRITER_ROLE} --project=${PROJECT_ID}

  # Grant Pub/Sub permissions
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${service_account}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=${PUBSUB_ADMIN_ROLE} --project=${PROJECT_ID}

  echo "Service Account created and permissions granted for ${service} service in ${REGION} region."
done