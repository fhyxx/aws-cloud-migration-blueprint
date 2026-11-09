output "vpc_id" {
  description = "Created VPC ID."
  value       = aws_vpc.this.id
}

output "subnet_ids" {
  description = "Subnet IDs keyed by logical subnet name."
  value       = { for key, subnet in aws_subnet.this : key => subnet.id }
}

output "route_table_ids" {
  description = "Route table IDs keyed by logical subnet name."
  value       = { for key, table in aws_route_table.this : key => table.id }
}

output "security_group_ids" {
  description = "Network security group IDs."
  value = {
    alb           = aws_security_group.alb.id
    app               = aws_security_group.app.id
    rds               = aws_security_group.rds.id
    efs               = aws_security_group.efs.id
    dms               = aws_security_group.dms.id
    mgn_staging       = aws_security_group.mgn_staging.id
    datasync_task     = aws_security_group.datasync_task.id
    datasync_endpoint = aws_security_group.datasync_endpoint.id
  }
}

output "vpn_connection_id" {
  description = "VPN connection ID when Site-to-Site VPN is enabled; otherwise null."
  value       = try(aws_vpn_connection.this[0].id, null)
}

output "datasync_endpoint_subnet_id" {
  description = "Dedicated subnet for the DataSync VPC service endpoint."
  value       = aws_subnet.this["datasync_endpoint"].id
}

output "datasync_endpoint_security_group_id" {
  description = "Security group to attach when activating the DataSync VPC service endpoint."
  value       = aws_security_group.datasync_endpoint.id
}

output "datasync_task_subnet_id" {
  description = "Dedicated subnet for DataSync task ENIs, with hybrid return routing."
  value       = aws_subnet.this["datasync_task"].id
}
