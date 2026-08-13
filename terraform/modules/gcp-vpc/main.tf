# GCP VPC Module — Regional subnets, Cloud NAT, firewall rules

resource "google_compute_network" "this" {
  name                    = var.name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "subnet" {
  count = length(var.subnets)

  name          = "${var.name}-subnet-${count.index}"
  ip_cidr_range = var.subnets[count.index].cidr
  region        = var.subnets[count.index].region
  network       = google_compute_network.this.id

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.subnets[count.index].pod_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.subnets[count.index].svc_cidr
  }
}

resource "google_compute_router" "this" {
  name    = "${var.name}-router"
  network = google_compute_network.this.id
  region  = var.subnets[0].region
}

resource "google_compute_router_nat" "this" {
  name                               = "${var.name}-nat"
  router                             = google_compute_router.this.name
  region                             = var.subnets[0].region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall: IAP SSH
resource "google_compute_firewall" "allow_ssh_iap" {
  name    = "${var.name}-allow-ssh-iap"
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["bastion"]
}

# Firewall: GKE control plane
resource "google_compute_firewall" "allow_gke_control_plane" {
  name    = "${var.name}-allow-gke-cp"
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["443", "10250"]
  }

  source_ranges = var.gke_control_plane_cidrs
  target_tags   = ["gke-node"]
}

# Firewall: GKE node-to-node
resource "google_compute_firewall" "allow_gke_nodes" {
  name    = "${var.name}-allow-gke-nodes"
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["30000-32767", "10250", "10255", "10256"]
  }

  source_tags = ["gke-node"]
  target_tags = ["gke-node"]
}

# Firewall: Load balancer health checks
resource "google_compute_firewall" "allow_lb_health_check" {
  name    = "${var.name}-allow-lb-hc"
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22",
    "209.85.152.0/22",
    "209.85.204.0/22",
  ]
  target_tags = ["gke-node", "webapp"]
}