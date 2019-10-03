resource "aws_iam_role" "datasync-instance-role" {
  name               = "datasync-instance-role-${var.env}"
  assume_role_policy = "${data.aws_iam_policy_document.ec2_assume_role.json}"
}

resource "aws_iam_role_policy" "datasync-instance-policy" {
  depends_on = ["aws_datasync_task.this"]

  name   = "datasync-policy-${var.datasync_agent["name"]}-${var.env}"
  role   = "${aws_iam_role.datasync-instance-role.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "datasync:*",
      "Resource": "${aws_datasync_task.this.arn}"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticfilesystem:Describe*",
      "Resource": "${data.aws_efs_file_system.this.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "datasync-instance-profile" {
  name = "datasync-instance-profile-${var.datasync_agent["name"]}-${var.env}"
  role = "${aws_iam_role.datasync-instance-role.name}"

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_security_group" "datasync-instance" {
  name        = "datasync-${var.datasync_agent["name"]}-${var.env}"
  description = "Datasync Security Group - ${var.datasync_agent["name"]}-${var.env}"
  vpc_id      = "${data.aws_vpc.this.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.this.cidr_block}", "${var.additional_cidrs}"]
    description = "SSH"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.this.cidr_block}", "${var.additional_cidrs}"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.this.cidr_block}", "${var.additional_cidrs}"]
    description = "HTTPS"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for Datasync agent to AWS Service endpoint"
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS"
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS"
  }

  egress {
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "NTP"
  }

  egress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "EFS/NFS"
  }

  tags = {
    Name = "datasync-agent-${var.datasync_agent["name"]}-${var.env}",
    env  = "${var.env}"
  }
}

resource "aws_instance" "datasync" {
  depends_on                           = ["data.aws_subnet.this"]

  ami                                  = "${data.aws_ami.datasync-agent.id}"
  instance_type                        = "${var.launch_template["instance_type"]}"
  instance_initiated_shutdown_behavior = "stop"

  disable_api_termination              = false
  iam_instance_profile                 = "${aws_iam_instance_profile.datasync-instance-profile.name}"
  key_name                             = "${var.ec2_key_pair}"

  vpc_security_group_ids               = ["${aws_security_group.datasync-instance.id}"]
  subnet_id                            = "${data.aws_subnet.this.0.id}"
  associate_public_ip_address          = false

  tags = {
    Name = "datasync-agent-instance-${var.datasync_agent["name"]}-${var.env}"
  }
}

resource "aws_datasync_agent" "this" {
  depends_on = ["aws_instance.datasync"]

  ip_address = "${data.aws_instance.datasync-instance.private_ip}"
  name       = "datasync-agent-${var.datasync_agent["name"]}-${var.env}"

  lifecycle {
    create_before_destroy = false
  }

  tags = {
    Name = "datasync-agent-${var.datasync_agent["name"]}-${var.env}",
    env  = "${var.env}"
  }
}

resource "aws_iam_role" "datasync-s3-access-role" {
  name               = "datasync-s3-access-role-${var.env}"
  assume_role_policy = "${data.aws_iam_policy_document.datasync_assume_role.json}"
}

resource "aws_iam_role_policy" "datasync-s3-access-policy" {
  name   = "datasync-s3-access-policy-${var.datasync_agent["name"]}-${var.env}"
  role   = "${aws_iam_role.datasync-s3-access-role.name}"
  policy = "${data.aws_iam_policy_document.bucket_access.json}"
}

resource "aws_datasync_location_s3" "this" {
  depends_on = ["aws_instance.datasync"]

  s3_bucket_arn = "${data.aws_s3_bucket.this.arn}"
  subdirectory  = "${var.datasync_location_s3_subdirectory}"

  s3_config {
    bucket_access_role_arn = "${aws_iam_role.datasync-s3-access-role.arn}"
  }

  tags = {
    Name = "datasync-agent-location-s3-${var.datasync_agent["name"]}-${var.env}",
    env  = "${var.env}"
  }
}

resource "aws_datasync_location_nfs" "this" {
  depends_on = ["aws_instance.datasync"]

  server_hostname = "${data.aws_efs_file_system.this.dns_name}"
  subdirectory    = "${var.datasync_location_nfs_subdirectory}"

  on_prem_config {
    agent_arns = ["${aws_datasync_agent.this.arn}"]
  }

  tags = {
    Name = "datasync-location-nfs-${var.datasync_agent["name"]}-${var.env}",
    env  = "${var.env}"
  }
}

resource "aws_cloudwatch_log_resource_policy" "this" {
  policy_document = "${data.aws_iam_policy_document.cloudwatch_log_group.json}"
  policy_name     = "datasync-clw-policy-${var.datasync_agent["name"]}-${var.env}"
}

resource "aws_cloudwatch_log_group" "this" {
  name = "datasync-${var.datasync_agent["name"]}-${var.env}"
  retention_in_days = 14

  tags = {
    Name = "datasync-${var.datasync_agent["name"]}-${var.env}"
    env  = "${var.env}"
  }
}

resource "aws_datasync_task" "this" {
  name                     = "datasync-task-${var.datasync_agent["name"]}-${var.env}"
  source_location_arn      = "${aws_datasync_location_s3.this.arn}"
  destination_location_arn = "${aws_datasync_location_nfs.this.arn}"
  cloudwatch_log_group_arn = "${join("", split(":*", aws_cloudwatch_log_group.this.arn))}"

  options {
    bytes_per_second       = -1
    verify_mode            = "${var.datasync_task_options["verify_mode"]}"
    posix_permissions      = "${var.datasync_task_options["posix_permissions"]}"
    preserve_deleted_files = "${var.datasync_task_options["preserve_deleted_files"]}"
    uid                    = "${var.datasync_task_options["uid"]}"
    gid                    = "${var.datasync_task_options["gid"]}"
    atime                  = "${var.datasync_task_options["atime"]}"
    mtime                  = "${var.datasync_task_options["mtime"]}"
  }

  tags = {
    Name = "datasync-task-${var.datasync_agent["name"]}-${var.env}",
    env  = "${var.env}"
  }
}