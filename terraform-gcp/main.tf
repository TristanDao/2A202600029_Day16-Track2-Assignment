provider "google" {
  project = var.project_id
  region  = var.region
}

# 1. Network: VPC & Subnet
resource "google_compute_network" "ai_vpc" {
  name                    = "ai-vpc-gcp"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private_subnet" {
  name          = "ai-private-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.ai_vpc.id
}

# 2. Cloud NAT (Cho phép VM trong Private Subnet ra Internet)
resource "google_compute_router" "router" {
  name    = "ai-router"
  region  = var.region
  network = google_compute_network.ai_vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "ai-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# 3. Firewall Rules
# Cho phép SSH từ IAP (Identity-Aware Proxy)
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh"
  network = google_compute_network.ai_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"] # Dải IP của Google IAP
}

# Cho phép Load Balancer truy cập cổng 8000
resource "google_compute_firewall" "allow_lb_healthcheck" {
  name    = "allow-lb-healthcheck"
  network = google_compute_network.ai_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8000"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"] # Dải IP của Google LB
}

# 4. Instance Template & Instance
resource "google_compute_instance" "ai_node" {
  name         = "ai-node-tinyllama"
  machine_type = "e2-medium" # 2 vCPU, 4GB RAM - Đủ cho TinyLlama
  zone         = "${var.region}-c"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id
    # Không có access_config = {} nghĩa là không có External IP
  }

  metadata_startup_script = file("${path.module}/user_data.sh")

  tags = ["ai-node"]
}

# 5. Load Balancer (Kiến trúc Lab 16)
# Health Check
resource "google_compute_health_check" "ai_health_check" {
  name = "ai-health-check"
  http_health_check {
    port = 8000
    request_path = "/health"
  }
}

# Unmanaged Instance Group (Để đưa VM vào Load Balancer)
resource "google_compute_instance_group" "ai_group" {
  name = "ai-instance-group"
  zone = "${var.region}-c"
  instances = [
    google_compute_instance.ai_node.id
  ]
  named_port {
    name = "http-api"
    port = 8000
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Backend Service
resource "google_compute_backend_service" "ai_backend" {
  name        = "ai-backend-service"
  port_name   = "http-api"
  protocol    = "HTTP"
  timeout_sec = 300
  health_checks = [google_compute_health_check.ai_health_check.id]

  backend {
    group = google_compute_instance_group.ai_group.id
  }
}

# URL Map
resource "google_compute_url_map" "ai_url_map" {
  name            = "ai-url-map"
  default_service = google_compute_backend_service.ai_backend.id
}

# Target HTTP Proxy
resource "google_compute_target_http_proxy" "ai_http_proxy" {
  name    = "ai-http-proxy"
  url_map = google_compute_url_map.ai_url_map.id
}

# Forwarding Rule (Public IP)
resource "google_compute_global_forwarding_rule" "ai_forwarding_rule" {
  name       = "ai-forwarding-rule"
  target     = google_compute_target_http_proxy.ai_http_proxy.id
  port_range = "80"
}
