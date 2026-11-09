output "dms_replication_task_arn" {
  description = "DMS full-load-and-CDC task ARN when enabled; task is created stopped."
  value       = try(aws_dms_replication_task.postgres_full_load_cdc[0].replication_task_arn, null)
}

output "datasync_nfs_to_efs_task_arn" {
  description = "DataSync NFS-to-EFS task ARN when enabled; task is not started."
  value       = try(aws_datasync_task.nfs_to_efs[0].arn, null)
}

output "archive_bucket_name" {
  description = "Private S3 archive destination bucket name when DataSync resources are enabled."
  value       = try(aws_s3_bucket.archive[0].bucket, null)
}
