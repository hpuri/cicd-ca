# Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable the Discovery Engine API (required for Vertex AI Search data stores and engines)
resource "google_project_service" "discoveryengine_api" {
  project            = var.project_id
  service            = "discoveryengine.googleapis.com"
  disable_on_destroy = false
}

# Create the Vertex AI Search data store
# Data ingestion from GCS is configured separately after this resource is created.
resource "google_discovery_engine_data_store" "vertex_ai_search_datastore" {
  data_store_id     = var.datastore_id       # Required: Unique ID for the data store
  display_name      = var.datastore_display_name # Required: Human-readable name
  location          = var.region             # Required: Geographic location ("us", "eu", or "global")
  industry_vertical = var.industry_vertical  # Required: Industry vertical
  content_config    = "CONTENT_REQUIRED"     # Required: Content configuration - set to CONTENT_REQUIRED for data from GCS

  solution_types = ["SOLUTION_TYPE_CHAT"] # Set solution type for chat

  # The GCS source configuration (like URI and data schema) is not part of this resource.
  # Data ingestion is a separate step after provisioning.

  depends_on = [google_project_service.discoveryengine_api]
}

# Create the Vertex AI Search conversational agent (Chat Engine)
resource "google_discovery_engine_chat_engine" "conversational_agent" {
  location       = var.region
  display_name   = var.agent_display_name
  project        = var.project_id
  collection_id  = "default_collection" # Use the default collection
  engine_id      = var.agent_id         # Unique ID for the agent

  # Associate the data store with the chat engine
  data_store_ids = [google_discovery_engine_data_store.vertex_ai_search_datastore.data_store_id]

  chat_engine_config {
    agent_creation_config {
      default_language_code = "en"           # Set a default language code
      time_zone             = "America/New_York" # Set an appropriate time zone
      business              = "My Company"   # Optional: Set a business name
    }
  }

  depends_on = [google_discovery_engine_data_store.vertex_ai_search_datastore]
}

# Output the ID of the created Vertex AI Search data store
output "datastore_id" {
  description = "The ID of the created Vertex AI Search data store."
  value       = google_discovery_engine_data_store.vertex_ai_search_datastore.data_store_id
}
# Output the full resource name (path) of the created Vertex AI Search data store
output "datastore_full_path" {
  description = "The full resource name (path) of the created Vertex AI Search data store."
  value       = google_discovery_engine_data_store.vertex_ai_search_datastore.name
}
# Output the ID of the created Vertex AI Search conversational agent (Chat Engine)
output "conversational_agent_id" {
  description = "The ID of the created Vertex AI Search conversational agent (Chat Engine)."
  value       = google_discovery_engine_chat_engine.conversational_agent.engine_id
}
