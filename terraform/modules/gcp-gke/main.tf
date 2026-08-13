# GCP GKE Module — Managed Kubernetes with Workload Identity, node pools, Binary Auth

resource "google_service_account" "gke_sa" {
  account_id   = "${var.name}-gke-sa"
  display_name = "GKE Node Service Account"
}

resource "google_project_iam_member" "gke_sa_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/storage.objectViewer",
    "roles/artifactregistry.reader",
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

# === GKE CLUSTER ===
resource "google_container_cluster" "this" {
  name     = var.name
  location = var.location
  project  = var.project_id

  # Regional cluster for HA
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_name
  subnetwork = var.subnet_name

  # Networking
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Dataplane V2 (eBPF)
  datapath_provider = "ADVANCED_DATAPATH"

  # Binary Authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Shielded Nodes
  enable_shielded_nodes = true

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Release Channel (stable)
  release_channel {
    channel = "STABLE"
  }

  # Maintenance Window
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T02:00:00Z"
      end_time   = "2024-01-01T06:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
    }
  }

  # Logging & Monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "STORAGE", "POD", "DEPLOYMENT", "STATEFULSET"]
    managed_prometheus {
      enabled = true
    }
  }

  # Private cluster
  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Node config for default pool
  node_config {
    service_account = google_service_account.gke_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    machine_type = "e2-standard-2"
    disk_size_gb = 100
    disk_type    = "pd-balanced"
    image_type   = "COS_CONTAINERD"

    labels = {
      env  = var.env
      team = var.team
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  depends_on = [
    google_project_iam_member.gke_sa_roles,
  ]
}

# === DEFAULT NODE POOL ===
resource "google_container_node_pool" "default" {
  name     = "${var.name}-default-pool"
  cluster  = google_container_cluster.this.name
  location = google_container_cluster.this.location

  node_count = var.default_pool_count

  autoscaling {
    min_node_count = var.default_pool_min
    max_node_count = var.default_pool_max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 100
    disk_type    = "pd-balanced"
    image_type   = "COS_CONTAINERD"
    service_account = google_service_account.gke_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      node_pool = "default"
      env       = var.env
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  depends_on = [google_container_cluster.this]
}

# === SPOT NODE POOL (cost savings for burst workloads) ===
resource "google_container_node_pool" "spot" {
  name     = "${var.name}-spot-pool"
  cluster  = google_container_cluster.this.name
  location = google_container_cluster.this.location

  node_count = var.spot_pool_count

  autoscaling {
    min_node_count = var.spot_pool_min
    max_node_count = var.spot_pool_max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 100
    disk_type    = "pd-balanced"
    image_type   = "COS_CONTAINERD"
    preemptible  = true
    service_account = google_service_account.gke_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      node_pool = "spot"
      env       = var.env
    }

    taint {
      key    = "spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  depends_on = [google_container_cluster.this]
}