#!/bin/bash

# Prompt user for the namespace name
read -p "Enter the name of the namespace to be deleted with status Terminated: " NAMESPACE

# Display the entered namespace name
echo "The namespace is: ${NAMESPACE}"

# Get the namespace information in JSON format, remove finalizer, and replace it
kubectl get namespace "$NAMESPACE" -o json | jq 'del(.spec.finalizers[0])' | kubectl replace --raw "/api/v1/namespaces/$NAMESPACE/finalize" -f -

# Check if the namespace is deleted
kubectl get namespaces | grep -q "${NAMESPACE}"
if [ $? -eq 0 ]; then
  echo "Namespace ${NAMESPACE} is still present."
else
  echo "Namespace ${NAMESPACE} has been successfully deleted."
fi
