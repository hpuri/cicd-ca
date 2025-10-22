
variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "The GCP multi-region for the Vertex AI Search resources ('us' or 'eu')."
  type        = string
  default     = "us" # Set the default region to "us"
}

variable "datastore_id" {
  description = "A unique ID for the Vertex AI Search data store."
  type        = string
}

variable "datastore_display_name" {
  description = "A human-readable display name for the Vertex AI Search data store."
  type        = string
}

variable "industry_vertical" {
  description = "The industry vertical for the data store ('GENERIC', 'MEDIA', or 'HEALTHCARE_FHIR'). Must be compatible with SOLUTION_TYPE_CHAT."
  type        = string
  default     = "GENERIC" # Set a default or provide your specific vertical
}

variable "agent_display_name" {
  description = "A human-readable display name for the Vertex AI Search conversational agent."
  type        = string
}

variable "agent_id" {
  description = "A unique ID for the Vertex AI Search conversational agent."
  type        = string
}
