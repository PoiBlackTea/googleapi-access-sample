resource "google_compute_network" "onprem_network" {
  name = "onprem-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "on_prem_subnetwork" {
  name          = "onprem-subnetwork"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.onprem_network.name
}

resource "google_compute_network" "gcp_vpc_network" {
  name = "gcp-vpc-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "gcp_vpc_subnetwork" {
  name          = "gcp-vpc-subnetwork"
  ip_cidr_range = "10.1.0.0/24"
  region        = var.region 
  network       = google_compute_network.gcp_vpc_network.name
}

module "private_service_connect" {
  source                     = "terraform-google-modules/network/google//modules/private-service-connect"
  version = "9.1.0"

  project_id                 = var.project_id
  network_self_link          = google_compute_network.gcp_vpc_network.self_link
  private_service_connect_ip = "10.0.255.2"
  forwarding_rule_target     = "all-apis"
}

resource "google_compute_router" "onprem-uscentral1-to-gcp-vpc" {
  name    = "simulation-onprem-to-gcp-tunnels"
  region  = "us-central1"
  network = google_compute_network.onprem_network.name
  project = var.project_id
}

resource "google_compute_router" "gcp-uscentral1-to-onprem-vpc" {
  name    = "simulation-gcp-to-onprem-tunnels"
  region  = "us-central1"
  network = google_compute_network.gcp_vpc_network.name
  project = var.project_id
}

resource "google_compute_address" "onprem_ip_address" {
  name = "onprem-ipaddress"
}

resource "google_compute_address" "gcp_ip_address" {
  name = "gcp-ipaddress"
}

resource "random_string" "secret" {
  length  = 16
}

module "vpn-onprem-internal" {
  source  = "terraform-google-modules/vpn/google"
  version = "3.1.1"

  project_id         = var.project_id
  network            = google_compute_network.onprem_network.name
  region             = var.region
  gateway_name       = "vpn-onprem-internal"
  tunnel_name_prefix = "vpn-tn-onprem-internal"
  shared_secret      = random_string.secret.result
  tunnel_count       = 1
  vpn_gw_ip          = google_compute_address.onprem_ip_address.address
  peer_ips           = [google_compute_address.gcp_ip_address.address]
  route_priority = 1000
  remote_subnet  = [google_compute_subnetwork.gcp_vpc_subnetwork.ip_cidr_range, "199.36.153.8/30", "10.0.255.0/24"]
}

module "vpn-manage-internal" {
  source  = "terraform-google-modules/vpn/google"
  version = "3.1.1"
  project_id         = var.project_id
  network            = google_compute_network.gcp_vpc_network.name
  region             = var.region
  gateway_name       = "vpn-gcp-internal"
  tunnel_name_prefix = "vpn-tn-gcp-internal"
  shared_secret      = random_string.secret.result
  tunnel_count       = 1
  vpn_gw_ip          = google_compute_address.gcp_ip_address.address
  peer_ips           = [google_compute_address.onprem_ip_address.address]
  route_priority = 1000
  remote_subnet  = [google_compute_subnetwork.on_prem_subnetwork.ip_cidr_range]
}

resource "google_compute_firewall" "allow_ssh_ingress_from_iap_to_onprem" {
  name    = "allow-ssh-ingress-from-iap-to-onprem"
  network = google_compute_network.onprem_network.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
}

resource "google_compute_firewall" "allow_ssh_ingress_from_iap_to_gcp" {
  name    = "allow-ssh-ingress-from-iap-to-gcp"
  network = google_compute_network.gcp_vpc_network.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
}

resource "google_compute_firewall" "allow_onprem_ingress_to_gcp" {
  name    = "allow-onprem-ingress-gcp"
  network = google_compute_network.gcp_vpc_network.self_link

  allow {
    protocol = "tcp"
    ports    = ["3128"]
  }

  source_ranges = [google_compute_subnetwork.on_prem_subnetwork.ip_cidr_range]
}


resource "google_service_account" "gce_demo_sa" {
  account_id   = "my-custom-sa"
  display_name = "Custom SA for VM Instance"
}

resource "google_project_iam_member" "role" {
  project  = var.project_id

  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.gce_demo_sa.email}"
}

resource "google_project_iam_member" "role_1" {
  project  = var.project_id

  role   = "roles/logging.logWriter"
  member = "serviceAccount:${google_service_account.gce_demo_sa.email}"
}

resource "google_project_iam_member" "role_2" {
  project  = var.project_id

  role   = "roles/monitoring.metricWriter"
  member = "serviceAccount:${google_service_account.gce_demo_sa.email}"
}

resource "google_compute_instance" "onprem_instance" {
  name         = "onprem-instance"
  machine_type = "e2-medium"
  allow_stopping_for_update = "true"
  zone         = "${var.region}-a"

  tags = ["onprem"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"

    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.on_prem_subnetwork.self_link
  }
}

resource "google_compute_instance" "gcp_instance" {
  name         = "gcp-instance"
  machine_type = "e2-medium"
  allow_stopping_for_update = "true"
  zone         = "${var.region}-a"

  tags = ["gcp"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"

    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.gcp_vpc_subnetwork.self_link
    
    access_config {
      nat_ip = ""
    }
  }

  metadata = {
    startup-script = "#! /bin/bash\napt update\napt upgrade\napt install squid -y\nsed -i 's/http_access deny all/http_access allow all/' /etc/squid/squid.conf\nsystemctl restart squid\n"
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.gce_demo_sa.email
    scopes = ["cloud-platform", "storage-ro", "monitoring-write", "logging-write"]
  }
}