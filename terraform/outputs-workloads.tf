output "application_load_balancer_dns" {
  description = "Public ALB DNS name when workload resources are enabled."
  value       = try(aws_lb.app[0].dns_name, null)
}

output "application_asg_name" {
  description = "Application Auto Scaling Group name when enabled."
  value       = try(aws_autoscaling_group.app[0].name, null)
}

output "rds_endpoint" {
  description = "Private RDS endpoint when workload resources are enabled."
  value       = try(aws_db_instance.app[0].address, null)
}

output "efs_id" {
  description = "Encrypted EFS file system ID when workload resources are enabled."
  value       = try(aws_efs_file_system.app[0].id, null)
}
