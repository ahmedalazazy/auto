#!/bin/bash

# Prompt for project ID
read -p "Enter the project ID: " PROJECT

# Run gcloud command and save output to CSV file
gcloud beta compute machine-images list --format="csv(NAME,STATUS,creation_timestamp)" --project="$PROJECT" > "${PROJECT}_machine_images.csv"

echo "Machine images list saved to ${PROJECT}_machine_images.csv"
