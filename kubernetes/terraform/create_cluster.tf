resource "google_container_cluster" "primary" {
  name = "${var.cluster_name}"
  zone = "${var.zone}"
  min_master_version = "${var.min_master_version}"
  initial_node_count = "${var.initial_node_count}"
  enable_legacy_abac = false    # Базовая аутентификация
#  network = "default-network"

# Базовая аутентификация (пустые значения - отключена)
  master_auth {
    username = "${var.master_auth_username}"
    password = "${var.master_auth_password}"
  }

# Конфигурация Nodes
  node_config {
    machine_type = "${var.machine_type}"
    image_type = "${var.image_type}"
    disk_size_gb = "${var.disk_size_gb}"
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append",
    ]
  }

# Addons configuratin
  addons_config {
    http_load_balancing {
      disabled = true
    }
    horizontal_pod_autoscaling {
      disabled = true
    }
    kubernetes_dashboard {
      disabled = true
    }
  }
}
