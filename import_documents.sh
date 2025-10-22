#!/bin/bash

# This script imports documents from the GCS bucket 'harrys-agentspace' into the Discovery Engine datastore 'harry-docs-datastore'.
# It dynamically fetches an authentication token using gcloud.
# comment out part is the basic cURL comand with gcloud auth token fetching
# additional spice and pepper to handle arguments, errors, and polling for operation completion are addeed
# also added code to handle URL variations between global and us-centra1
# curl -X POST \
#   -H "Authorization: Bearer $(gcloud auth print-access-token)" \
#   -H "Content-Type: application/json" \
#   -d '{
#     "gcsSource": {
#       "inputUris": ["gs://harrys-agentspace/*"]
#     }
#   }' \
#   "https://us-discoveryengine.googleapis.com/v1/projects/uhgaa-434720/locations/us/collections/default_collection/dataStores/harry-docs-datastore/branches/default_branch/documents:import"

# --- Configuration ---
# Replace these with your specific Discovery Engine and GCS details.
PROJECT_ID="uhgaa-434720"
LOCATION="us" # Use "global" for global datastores
COLLECTION_ID="default_collection"
DATASTORE_ID="harry-docs-datastore"
BRANCH_ID="default_branch"
GCS_BUCKET_NAME="harrys-agentspace"

# --- Script ---

set -euo pipefail

# Function to display script usage
usage() {
  echo "Usage: $0 [-p <PROJECT_ID>] [-l <LOCATION>] [-c <COLLECTION_ID>] [-d <DATASTORE_ID>] [-b <BRANCH_ID>] [-g <GCS_BUCKET_NAME>]"
  echo "  -p, --project-id      GCP Project ID (default: ${PROJECT_ID})"
  echo "  -l, --location        Discovery Engine Location (e.g., us, global) (default: ${LOCATION})"
  echo "  -c, --collection-id   Collection ID (default: ${COLLECTION_ID})"
  echo "  -d, --datastore-id    Datastore ID (default: ${DATASTORE_ID})"
  echo "  -b, --branch-id       Branch ID (default: ${BRANCH_ID})"
  echo "  -g, --gcs-bucket      GCS Bucket Name for import source (default: ${GCS_BUCKET_NAME})"
  echo "  -h, --help            Display this help message"
  exit 1
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -p|--project-id) PROJECT_ID="$2"; shift ;;
    -l|--location) LOCATION="$2"; shift ;;
    -c|--collection-id) COLLECTION_ID="$2"; shift ;;
    -d|--datastore-id) DATASTORE_ID="$2"; shift ;;
    -b|--branch-id) BRANCH_ID="$2"; shift ;;
    -g|--gcs-bucket) GCS_BUCKET_NAME="$2"; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown parameter passed: $1"; usage ;;
  esac
  shift
done

# Check for required commands
if ! command -v gcloud &> /dev/null; then
    echo "gcloud command could not be found. Please install Google Cloud SDK."
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "curl command could not be found. Please install curl."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "jq command could not be found. Please install jq to parse API responses."
    exit 1
fi

# Get access token from gcloud
ACCESS_TOKEN=$(gcloud auth print-access-token)
if [ -z "${ACCESS_TOKEN}" ]; then
    echo "Failed to get gcloud access token. Please run 'gcloud auth login'."
    exit 1
fi

# Construct the base API URL based on the location
if [[ "${LOCATION}" == "global" ]]; then
  BASE_API_URL="https://discoveryengine.googleapis.com"
else
  BASE_API_URL="https://${LOCATION}-discoveryengine.googleapis.com"
fi

# API URL for the import operation
API_URL="${BASE_API_URL}/v1/projects/${PROJECT_ID}/locations/${LOCATION}/collections/${COLLECTION_ID}/dataStores/${DATASTORE_ID}/branches/${BRANCH_ID}/documents:import"

# JSON Payload
JSON_PAYLOAD=$(cat <<EOF
{
  "gcsSource": {
    "inputUris": ["gs://${GCS_BUCKET_NAME}/*"]
  }
}
EOF
)

echo "Importing documents..."
echo "Project ID: ${PROJECT_ID}"
echo "Location: ${LOCATION}"
echo "Datastore: ${DATASTORE_ID}"
echo "Source Bucket: gs://${GCS_BUCKET_NAME}/*"

# Make the API call and capture the response
OPERATION_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${JSON_PAYLOAD}" \
  "${API_URL}")

# Extract the operation name
OPERATION_NAME=$(echo "${OPERATION_RESPONSE}" | jq -r '.name')

# Check if the operation name was successfully extracted
if [ -z "${OPERATION_NAME}" ] || [ "${OPERATION_NAME}" == "null" ]; then
  echo "Failed to initiate import operation. Response:"
  echo "${OPERATION_RESPONSE}" | jq .
  exit 1
fi

echo -e "\nImport operation initiated. Name: ${OPERATION_NAME}"
echo "Polling for completion status..."

# Poll for the operation status
STATUS_API_URL="${BASE_API_URL}/v1/${OPERATION_NAME}"

while true; do
  STATUS_RESPONSE=$(curl -s -X GET \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "${STATUS_API_URL}")

  IS_DONE=$(echo "${STATUS_RESPONSE}" | jq -r '.done')

  if [[ "${IS_DONE}" == "true" ]]; then
    echo "Operation has completed."
    echo "Final Status:"
    echo "${STATUS_RESPONSE}" | jq .
    # Check if there was an error in the final response
    if echo "${STATUS_RESPONSE}" | jq -e '.error' > /dev/null; then
      exit 1 # Exit with an error code if the operation failed
    else
      exit 0 # Exit successfully
    fi
  fi

  echo "Still in progress, checking again in 30 seconds..."
  sleep 30
done