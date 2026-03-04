variable "tf_state_bucket_name" {}
variable "environment" {}
variable "log_bucket_name" {}
variable "backup_bucket_name" {}
variable "logs" {}



/*So rather than using one bucket for everything, we will use separate buckets for separate concerns.
For example, one bucket for Terraform state for strict access control, one bucket for backup storage
for retention and immutability, one bucket for application uploads for different lifecycle,
and one bucket for logs, compliance, plus auditing.*/


resource "aws_s3_bucket" "terraform_state" {
  bucket = var.tf_state_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "terraform-state"
    Environment = var.environment
  }
}

//Block Public Access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

//Enable Versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}//If someone corrupts state, you restore previous version.

resource "aws_kms_key" "tf_state_key" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.tf_state_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}//with SSE-KMS i can manage keys ,rotation access control ,full logging and best for production and sensitive data


//Enable Access Logging
resource "aws_s3_bucket" "log_bucket" {
  bucket = var.log_bucket_name
}

resource "aws_s3_bucket_logging" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "terraform-state-logs/"
}


//Add Lifecycle Policy
resource "aws_s3_bucket_lifecycle_configuration" "log_lifecycle" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "log-expiry"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}


//Backup Bucket (EKS + RDS)
//WORM(write once read many) bucket
resource "aws_s3_bucket" "backup_bucket" {
  bucket              = var.backup_bucket_name
  object_lock_enabled = true
}

resource "aws_s3_bucket_object_lock_configuration" "backup_lock" {
  bucket = aws_s3_bucket.backup_bucket.id

  rule {
    default_retention {
      mode = "GOVERNANCE" // admin can do changes to the bucket
      days = 90
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backup_lifecycle" {
  bucket = aws_s3_bucket.backup_bucket.id

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# DEVSECSOPS
/*
force HTTPS only
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": ["arn:aws:s3:::bucket-name/*"],
  "Condition": {
    "Bool": {
      "aws:SecureTransport": "false"
    }
  }
}
*/


/*
Deny Unencrypted Uploads
"Condition": {
  "StringNotEquals": {
    "s3:x-amz-server-side-encryption": "aws:kms"
  }
}

*/


/*
Deny Delete for Non-Admin
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyDeleteForNonAdmin",
      "Effect": "Deny",
      "Principal": "*",
      "Action": [
        "s3:DeleteObject",
        "s3:DeleteObjectVersion"
      ],
      "Resource": "arn:aws:s3:::your-bucket-name/*",
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalArn": "arn:aws:iam::123456789012:role/S3-Admin-Role"
        }
      }
    }
  ]
}
*/

//Production Lifecycle Policy

resource "aws_s3_bucket" "logs" {
  bucket = var.logs
}

resource "aws_s3_bucket_lifecycle_configuration" "logs_lifecycle" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "log-archive-strategy"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }//Prevents storage leak from failed uploads

    expiration {
      days = 730
    }
  }
}//retrieval will take 12–48 hours