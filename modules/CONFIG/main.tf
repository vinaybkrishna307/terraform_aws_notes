

resource "aws_iam_role" "config_role" {
  name = "aws-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}


//This tells AWS Config which resources to track.
resource "aws_config_configuration_recorder" "main" {
  name     = "config-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported = true
  }
}//EC2,Security Groups,S3,IAM,RDS,EBS,VPC


//Delivery Channel (Where logs go)
resource "aws_s3_bucket" "config_bucket" {
  bucket = "mikey-aws-config-bucket"

  tags = {
    Name = "aws-config-logs"
  }
}

/*
This stores:
  configuration snapshots
  resource history
  compliance reports
*/

resource "aws_config_delivery_channel" "main" {
  name           = "config-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config_bucket.bucket
}



//Start the Recorder
resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true
}


//Example Rule: Block Public S3 Buckets
resource "aws_config_config_rule" "s3_public_block" {
  name = "s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }
}

/*
If someone makes a bucket public:
Bucket → NON_COMPLIANT
Security team gets alerted.
*/

resource "aws_config_config_rule" "restricted_ssh" {
  name = "restricted-ssh"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }
}

/*
If a security group has:
  0.0.0.0/0 → port 22
AWS Config marks it:
  NON_COMPLIANT
*/