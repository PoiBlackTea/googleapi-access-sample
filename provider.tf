terraform {
    required_providers {
        google = {
            source = "hashicorp/google"
            version = "5.36.0"
        }
        random = {
            source  = "hashicorp/random"
            version = "3.6.2"
        }
    }
}

provider "google" {
    # Configuration options
    project = var.project_id
    region = "us-central1"
}
