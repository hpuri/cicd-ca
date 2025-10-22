#!/bin/bash
# Author: Harry Puri 
# PLEASE DO NOT USE THIS SCRIPT WITHOUT MODIFYING IT TO YOUR NEEDS AND TESTING IT FIRST
# PAY ATTENTION TO THE PROJECT ID, AGENT ID, LOCATION(also 2 spots in URL), BUCKET NAME, AND OBJECT NAME

# TLDR: Thisis a script to export a Conversational agent to a GCS bucket.
# commented out part is the basic cURL comand with gcloud auth token fetching
# additional spice and pepper to handle arguments, errors, and polling for operation completion are addeed
# also added code to handle URL variations between global and us-centra1
# curl -X POST \
#   -H "X-Goog-User-Project: uhgaa-434720" \
#   -H "Authorization: Bearer $(gcloud auth print-access-token)" \
#   -H "Content-Type: application/json" \
#   "https://dialogflow.googleapis.com/v3/projects/uhgaa-434720/locations/global/agents/4d177e4c-75ec-40ae-8bc2-9327f949477a:export" \
#   -d '{
#   "agentUri": "gs://harrys-agentspace/pain-rx2",
#   "dataFormat": "JSON_PACKAGE",
#   "includeBigqueryExportSettings": true
# }'



# --- Configuration ---
# https://cloud.google.com/dialogflow/cx/docs/reference/rest/v3/projects.locations.agents/export
# Replace these with your specific agent details, or provide them as command-line arguments.
PROJECT_ID="uhgaa-434720"
AGENT_ID="4d177e4c-75ec-40ae-8bc2-9327f949477a"
LOCATION="global"
BUCKET_NAME="harrys-agentspace"
OBJECT_NAME="pain-rx2"

# --- Script ---

set -euo pipefail

# Function to display script usage
usage() {
  echo "Usage: $0 [-p <PROJECT_ID>] [-a <AGENT_ID>] [-l <LOCATION>] [-b <BUCKET_NAME>] [-o <OBJECT_NAME>]"
  echo "  -p, --project-id   GCP Project ID (default: ${PROJECT_ID})"
  echo "  -a, --agent-id     Dialogflow CX Agent ID (default: ${AGENT_ID})"
  echo "  -l, --location     Dialogflow CX Agent Location (default: ${LOCATION})"
  echo "  -b, --bucket-name  GCS Bucket Name for export (default: ${BUCKET_NAME})"
  echo "  -o, --object-name  GCS Object Name for the exported agent (default: ${OBJECT_NAME})"
  echo "  -h, --help         Display this help message"
  exit 1
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -p|--project-id) PROJECT_ID="$2"; shift ;; 
    -a|--agent-id) AGENT_ID="$2"; shift ;; 
    -l|--location) LOCATION="$2"; shift ;; 
    -b|--bucket-name) BUCKET_NAME="$2"; shift ;; 
    -o|--object-name) OBJECT_NAME="$2"; shift ;; 
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
  BASE_API_URL="https://dialogflow.googleapis.com"
else
  BASE_API_URL="https://${LOCATION}-dialogflow.googleapis.com"
fi

# API URL for the export operation ****NOTE the URL***
# sample for us-central1 https://us-central1-dialogflow.googleapis.com/v3/projects/{project_id}/locations/us-central1/agents/{agent_id}:export
# sample for global: https://dialogflow.googleapis.com/v3/projects/{project_id}/locations/global/agents/{agent_id}:restore
API_URL="${BASE_API_URL}/v3/projects/${PROJECT_ID}/locations/${LOCATION}/agents/${AGENT_ID}:export"

# JSON Payload
JSON_PAYLOAD=$(cat <<EOF
{
  "agentUri": "gs://${BUCKET_NAME}/${OBJECT_NAME}",
  "dataFormat": "JSON_PACKAGE",
  "includeBigqueryExportSettings": true
}
EOF
)

echo "Exporting agent..."
echo "Project ID: ${PROJECT_ID}"
echo "Agent ID: ${AGENT_ID}"
echo "Location: ${LOCATION}"
echo "Bucket: gs://${BUCKET_NAME}/${OBJECT_NAME}"

# Make the API call and capture the response
OPERATION_RESPONSE=$(curl -s -X POST \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  "${API_URL}" \
  -d "${JSON_PAYLOAD}")

# Extract the operation name
OPERATION_NAME=$(echo "${OPERATION_RESPONSE}" | jq -r '.name')

# Check if the operation name was successfully extracted
if [ -z "${OPERATION_NAME}" ] || [ "${OPERATION_NAME}" == "null" ]; then
  echo "Failed to initiate export operation. Response:"
  echo "${OPERATION_RESPONSE}" | jq .
  exit 1
fi

echo -e "\nExport operation initiated. Name: ${OPERATION_NAME}"
echo "Polling for completion status..."

# Poll for the operation status
STATUS_API_URL="${BASE_API_URL}/v3/${OPERATION_NAME}"

while true; do
  STATUS_RESPONSE=$(curl -s -X GET \
    -H "X-Goog-User-Project: ${PROJECT_ID}" \
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

  echo "Still in progress, checking again in 10 seconds..."
  sleep 10
done