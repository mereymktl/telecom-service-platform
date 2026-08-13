output "network_id"    { value = google_compute_network.this.id }
output "network_name"  { value = google_compute_network.this.name }
output "subnet_ids"    { value = google_compute_subnetwork.subnet[*].id }
output "subnet_names"  { value = google_compute_subnetwork.subnet[*].name }
