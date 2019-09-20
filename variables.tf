variable "vpc_id" {
  type        = "string"
  description = "VPC id"
}

variable "subnet_ids" {
  type        = "list"
  description = "A list of Subnet ids"
}

variable "additional_cidrs" {
  type        = "list"
  description = "A list of cidrs to limit security groups"
}

variable "file_system_id" {
  type        = "string"
  description = "File system id"
}

variable "security_group_arns" {
  type        = "list"
  description = "A list of AWS EC2 Security Group ARNs"
}

variable "ec2_key_pair" {
  type        = "string"
  description = "ec2 key-pair"
}

variable "datasync_agent" {
  type        = "map"
  description = "A Map of datasync agent variables"
}

variable "datasync_task_tags" {
  type        = "map"
  description = "A map of tags in addition to the default tags for the datasync-task object"
}

variable "datasync_location_s3_subdirectory" {
  type        = "string"
  description = "AWS S3 Bucket path"
  default     = "/"
}

variable "datasync_location_nfs_subdirectory" {
  type        = "string"
  description = "NFS path"
  default     = "/"
}

variable "bucket_name" {
  type        = "string"
  description = "AWS S3 Bucket name"
}

variable "ec2_fleet" {
  type        = "map"
  description = "A map of EC2 Fleet variables"
  default = {
    target_capacity_type = "on-demand"
    target_capacity      = "1"
    terminate_instances  = "true"
    replace_instances    = "true"
    allocation_strategy  = "lowestPrice"
  }
}

variable "launch_template" {
  type        = "map"
  description = "A map of AWS Launch Template variables"
  default = {
    instance_type       = "m5.2xlarge"
  }
}

variable "aws_region" {
  type        = "map"
  description = "a map of an AWS Region name and alias"
  default = {
    name  = "us-east-1"
    alias = "ue1"
  }
}

variable "env" {
  type        = "string"
  description = "Environment"
}

variable "datasync_task_options" {
  type        = "map"
  description = "A map of datasync_task options block"
  default = {
    verify_mode            = "POINT_IN_TIME_CONSISTENT"
    posix_permissions      = "NONE"
    preserve_deleted_files = "REMOVE"
    uid                    = "NONE"
    gid                    = "NONE"
    atime                  = "NONE"
    mtime                  = "NONE"
    bytes_per_second       = "-1"
  }
}