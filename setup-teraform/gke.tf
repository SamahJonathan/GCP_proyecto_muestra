resource "google_container_cluster" "primary" {
    name ="mi-cluster-gke"
    location = "us-east1-b"
    initial_node_count = 1
    node_config {
      machine_type = "e2-medium" # GKE requiere mas ram
      oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    }
  
  
}