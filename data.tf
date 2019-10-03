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

data "aws_ami" "datasync-agent" {
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

data "aws_instance" "datasync-instance" {
  depends_on    = ["aws_instance.datasync"]

  filter {
    name   = "tag:Name"
    values = ["datasync-agent-instance-${var.datasync_agent["name"]}-${var.env}"]
  }
}

data "aws_iam_policy_document" "cloudwatch_log_group" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutLogEventsBatch",
    ]
    resources = ["${aws_cloudwatch_log_group.this.arn}"]
    principals {
      identifiers = ["datasync.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "datasync_assume_role" {
  statement {
    actions = ["sts:AssumeRole",]
    principals {
      identifiers = ["datasync.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole",]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "bucket_access" {
  statement {
    actions = ["s3:*",]
    resources = [
      "${data.aws_s3_bucket.this.arn}",
      "${data.aws_s3_bucket.this.arn}:/*",
      "${data.aws_s3_bucket.this.arn}:job/*"
    ]
  }
}