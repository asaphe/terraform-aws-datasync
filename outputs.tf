output "datasync_vpc_endpoint" {
  value = "${aws_vpc_endpoint.this.id}"
}

output "datasync_instance" {
  value = "${aws_instance.this.id}"
}

output "datasync_agent" {
  value = "${aws_datasync_agent.this.id}"
}

output "datasync_location_s3" {
  value = "${aws_datasync_location_s3.this.id}"
}

output "datasync_location_nfs" {
  value = "${aws_datasync_location_nfs.this.id}"
}

output "datasync_task_arn" {
  value = "${aws_datasync_task.this.arn}"
}

output "cloudwatch_log_group_arn" {
  value = "${data.aws_cloudwatch_log_group.this.arn}"
}
