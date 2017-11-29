variable project {
  description = "Project ID"
  default = "infra-179710"
}

variable region {
  description = "Region"
  default = "europe-west1"
}

variable cluster_name {
  description = "Cluster name"
  default = "cluster-1"
}

variable zone {
  description = "Zone"
  default = "us-central1-a"
}

variable min_master_version {
  description = "The minimum version of the master"
  default = "1.8.3-gke.0"
}

variable initial_node_count {
  description = "The number of nodes to create in this cluster"
  default = "2"
}

variable master_auth_username {
  description = "The username to use for HTTP basic authentication when accessing the Kubernetes master endpoint"
  default = ""
}

variable master_auth_password {
  description = "The password to use for HTTP basic authentication when accessing the Kubernetes master endpoint"
  default = ""
}

variable machine_type {
  description = "The name of a Google Compute Engine machine type"
  default = "g1-small"
}

variable image_type {
  description = "The image type to use for this node"
  default = "COS"
}

variable disk_size_gb {
  description = "Size of the disk attached to each node, specified in GB"
  default = "20"
}
