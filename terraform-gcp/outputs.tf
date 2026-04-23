output "lb_ip" {
  description = "Public IP of the Load Balancer"
  value       = google_compute_global_forwarding_rule.ai_forwarding_rule.ip_address
}

output "instance_private_ip" {
  description = "Private IP of the AI Node"
  value       = google_compute_instance.ai_node.network_interface[0].network_ip
}

output "endpoint_url" {
  description = "The endpoint for AI chat completions"
  value       = "http://${google_compute_global_forwarding_rule.ai_forwarding_rule.ip_address}/v1/chat/completions"
}
