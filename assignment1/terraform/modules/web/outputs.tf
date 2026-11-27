output "vpc_id" {
  description = "ID of the environment VPC."
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Public subnet IDs keyed by stable names."
  value       = { for key, subnet in aws_subnet.public : key => subnet.id }
}

output "instance_id" {
  description = "EC2 web server instance ID."
  value       = aws_instance.web.id
}

output "web_public_ip" {
  description = "Public IP of the web server."
  value       = aws_instance.web.public_ip
}

output "web_url" {
  description = "HTTP endpoint for application verification."
  value       = "http://${aws_instance.web.public_ip}/"
}

output "environment" {
  description = "Deployment environment."
  value       = var.environment
}

output "app_version" {
  description = "Deployed application version."
  value       = var.app_version
}
