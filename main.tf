provider "aws" {
  region = "${var.aws_region["name"]}"
}

data "aws_vpc" "this" {
  id = "${var.vpc_id}"
}

data "aws_subnet" "this" {
  count  = "${length(var.subnet_ids)}"

  vpc_id = "${data.aws_vpc.this.id}"
  id     = "${var.subnet_ids[count.index]}"
}

data "aws_efs_file_system" "this" {
  file_system_id = "${var.file_system_id}"
}

data "aws_s3_bucket" "this" {
  bucket = "${var.bucket_name}"
}

data "aws_ami" "this" {
  most_recent = true

  filter {
    name   = "name"
    values = ["aws-datasync-*"]
  }

  owners = ["633936118553"] # AMZN
}

data "aws_vpc_endpoint_service" "this" {
  service = "datasync"
}

data "aws_iam_policy_document" "this" {
  depends_on = ["aws_cloudwatch_log_group.this"]

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutLogEventsBatch",
    ]

    resources = ["${data.aws_cloudwatch_log_group.this.arn}"]

    principals {
      identifiers = ["datasync.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_instance" "this" {
  depends_on  = ["aws_instance.this"]
  instance_id = "${aws_instance.this.id}"
}

data "aws_cloudwatch_log_group" "this" {
  depends_on = ["aws_cloudwatch_log_group.this"]
  name       = "${aws_cloudwatch_log_group.this.name}"
}

resource "aws_security_group" "this_endpoint" {
  name        = "datasync-endpoint-${var.datasync_agent["name"]}-${var.env}"
  description = "Datasync Endpoint Security Group - ${var.datasync_agent["name"]}-${var.env}"
  vpc_id      = "${data.aws_vpc.this.id}"

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.this.cidr_block}"]
    description = "All Traffic [VPC]"
  }

  egress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.this.cidr_block}"]
    description = "All Traffic [VPC]"
  }

  tags = {
    Name = "datasync-endpoint-${var.datasync_agent["name"]}-${var.env}",
    env  = "${var.env}"
  }
}

resource "aws_vpc_endpoint" "this" {
  vpc_endpoint_type  = "Interface"
  vpc_id             = "${data.aws_vpc.this.id}"
  subnet_ids         = ["${data.aws_subnet.this.*.id}"]
  security_group_ids = ["${aws_security_group.this_endpoint.id}"]
  service_name       = "${data.aws_vpc_endpoint_service.this.service_name}"
  auto_accept        = true
}

resource "aws_security_group" "this" {
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
    description = "Datasync agent Auth [80-auto-closed by datasync agent]"
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
    cidr_blocks = ["${data.aws_vpc.this.cidr_block}"]
    description = "EFS"
  }

  tags = {
    Name = "datasync-agent-${var.datasync_agent["name"]}-${var.env}",
    env  = "${var.env}"
  }
}
# TODO: Convert to AWS EC2 Fleet of 1 to ensure HA
resource "aws_instance" "this" {
  depends_on                           = ["data.aws_subnet.this"]

  ami                                  = "${data.aws_ami.this.id}"
  instance_type                        = "${var.launch_template["instance_type"]}"
  instance_initiated_shutdown_behavior = "stop"

  disable_api_termination              = false
  iam_instance_profile                 = "${aws_iam_instance_profile.this_instance.name}"
  key_name                             = "${var.ec2_key_pair}"

  vpc_security_group_ids               = ["${aws_security_group.this.id}"]
  subnet_id                            = "${data.aws_subnet.this.0.id}"
  associate_public_ip_address          = false

  tags = {
    Name = "datasync-agent-instance-${var.datasync_agent["name"]}-${var.env}"
  }
}

resource "aws_datasync_agent" "this" {
  depends_on = ["data.aws_instance.this"]

  ip_address = "${data.aws_instance.this.private_ip}"
  name       = "datasync-agent-${var.datasync_agent["name"]}-${var.env}"

  tags = {
    Name = "datasync-agent-${var.datasync_agent["name"]}-${var.env}",
    env  = "${var.env}"
  }
}

resource "aws_datasync_location_s3" "this" {
  depends_on = ["data.aws_instance.this"]

  s3_bucket_arn = "${data.aws_s3_bucket.this.arn}"
  subdirectory  = "${var.datasync_location_s3_subdirectory}"

  s3_config {
    bucket_access_role_arn = "${aws_iam_role.this.arn}"
  }

  tags = {
    Name = "datasync-agent-location-s3-${var.datasync_agent["name"]}-${var.env}",
    env  = "${var.env}"
  }
}

resource "aws_datasync_location_nfs" "this" {
  depends_on      = ["data.aws_instance.this"]

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

resource "aws_datasync_task" "this" {
  depends_on = ["data.aws_instance.this", "aws_datasync_location_nfs.this", "aws_datasync_location_s3.this", "aws_cloudwatch_log_group.this"]

  source_location_arn      = "${aws_datasync_location_s3.this.arn}"
  name                     = "datasync-task-${var.datasync_agent["name"]}-${var.env}"
  destination_location_arn = "${aws_datasync_location_nfs.this.arn}"

#  cloudwatch_log_group_arn = "${data.aws_cloudwatch_log_group.this.arn}"

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

resource "aws_cloudwatch_log_group" "this" {
  name = "datasync-${var.datasync_agent["name"]}-${var.env}"
  retention_in_days = 14
  tags = {
    Name = "datasync-${var.datasync_agent["name"]}-${var.env}"
    env  = "${var.env}"
  }
}

resource "aws_cloudwatch_log_resource_policy" "this" {
  policy_document = "${data.aws_iam_policy_document.this.json}"
  policy_name     = "datasync-clw-policy-${var.datasync_agent["name"]}-${var.env}"
}

resource "aws_iam_role" "this" {
  name = "datasync-role-${var.datasync_agent["name"]}-${var.env}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "datasync.amazonaws.com"
      }
    }
  ]
}
EOF

  tags = {
    Name = "datasync-role-${var.datasync_agent["name"]}-${var.env}",
    env  = "${var.env}"
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "datasync-s3-access-policy-${var.datasync_agent["name"]}-${var.env}"
  role   = "${aws_iam_role.this.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "s3:*",
      "Effect": "Allow",
      "Resource": [
        "${data.aws_s3_bucket.this.arn}",
        "${data.aws_s3_bucket.this.arn}:/*",
        "${data.aws_s3_bucket.this.arn}:job/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "this_instance" {
  name        = "datasync-instance-role-${var.datasync_agent["name"]}-${var.env}"
  description = "Role for the Datasync-agent Instance"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
EOF

  tags = {
    Name = "datasync-instance-role-${var.datasync_agent["name"]}-${var.env}",
    env  = "${var.env}"
  }
}

resource "aws_iam_instance_profile" "this_instance" {
  name = "datasync-instance-profile-${var.datasync_agent["name"]}-${var.env}"
  role = "${aws_iam_role.this_instance.name}"
}

resource "aws_iam_role_policy" "this_instance" {
  name   = "datasync-policy-${var.datasync_agent["name"]}-${var.env}"
  role   = "${aws_iam_role.this_instance.name}"

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