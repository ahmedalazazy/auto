#!/bin/bash

# Set the ACR name
ACR_NAME="<Your_ACR_Name>"

# Authenticate to Azure (skip this in Azure Automation if using managed identity)
# az login

# Get list of repositories in the ACR
REPOS=$(az acr repository list --name $ACR_NAME --output tsv)

# Check if the ACR repository list retrieval was successful
if [ $? -ne 0 ]; then
    echo "Failed to fetch the repositories. Please check your ACR name and Azure CLI authentication."
    exit 1
fi

# Loop through each repository
for REPO in $REPOS
do
    echo "Processing repository: $REPO"

    # Get list of images (tags) sorted by last update time (descending)
    IMAGES=$(az acr repository show-tags --name $ACR_NAME --repository $REPO --orderby time_desc --output tsv)

    # Check if image retrieval was successful
    if [ $? -ne 0 ]; then
        echo "Failed to fetch images for repository: $REPO. Skipping..."
        continue
    fi

    # Convert images to an array
    IMAGES_ARRAY=($IMAGES)

    # Check if number of images is greater than 5
    if [ ${#IMAGES_ARRAY[@]} -gt 5 ]; then
        echo "Repository $REPO has more than 5 images. The following images will be deleted (if confirmed):"

        # Loop through images starting from the 6th one (index 5) and print them
        for (( i=5; i<${#IMAGES_ARRAY[@]}; i++ ))
        do
            IMAGE_TAG=${IMAGES_ARRAY[$i]}
            echo "$REPO:$IMAGE_TAG"
        done

        # Ask for confirmation
        read -p "Do you want to delete the above images? (yes/no): " CONFIRMATION

        # Trim whitespace and convert to lowercase
        CONFIRMATION=$(echo "$CONFIRMATION" | xargs | tr '[:upper:]' '[:lower:]')

        if [[ "$CONFIRMATION" == "yes" ]]; then
            echo "Deleting images from $REPO..."
            # Proceed with deletion
            for (( i=5; i<${#IMAGES_ARRAY[@]}; i++ ))
            do
                IMAGE_TAG=${IMAGES_ARRAY[$i]}
                echo "Deleting image: $REPO:$IMAGE_TAG"
                az acr repository delete --name $ACR_NAME --image "$REPO:$IMAGE_TAG" --yes
            done
        else
            echo "Skipping deletion for repository: $REPO"
        fi
    else
        echo "Repository $REPO has 5 or fewer images. No action required."
    fi
done

echo "Script execution completed."
