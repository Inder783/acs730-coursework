output "vpc_id" {
  value = module.web.vpc_id
}

output "subnet_ids" {
  value = module.web.subnet_ids
}

output "instance_id" {
  value = module.web.instance_id
}

output "web_public_ip" {
  value = module.web.web_public_ip
}

output "web_url" {
  value = module.web.web_url
}

output "environment" {
  value = module.web.environment
}

output "app_version" {
  value = module.web.app_version
}
