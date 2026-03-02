/*Who can do what, on which resource, under what conditions.*/


/*
Identity Types
Permanent credentials
Used rarely in modern setups (avoid long-term access keys)
*/

/*
IAM Role
Temporary credentials via STS.
*/

resource "aws_iam_role" "ec2_role" {
  name = "ec2-app-role"

  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# policies defines permission given to that resource

/*
Identity based policy
given to grps,users, roles

{
  "Effect": "Allow",
  "Action": ["s3:GetObject"],
  "Resource": "arn:aws:s3:::my-bucket/*"
}
*/

/*
Resource-Based Policies

attached directly to resources
Example: S3 bucket policy allowing third-party account access.
*/

/*

IAM evaluates in this order:

1) Explicit Deny

2) Explicit Allow

3) Default Deny

*/


/*

Trust policy = Who can enter the house
Permission policy = What rooms they can access

*/

# trust policy or assume role policy
/*{
{
  "Effect": "Allow",
  "Principal": {
    "Service": "ec2.amazonaws.com"
  },
  "Action": "sts:AssumeRole"  //STS issues temporary credentials when:Role is assumed
}
}*/

/*

what happens when role is assumed

1) User or service calls sts:AssumeRole

2) AWS validates trust policy

3) STS generates temporary credentials

4) Caller uses those credentials

*/


# How to Give Third-Party Access

/*

"Condition": {
  "StringEquals": {
    "sts:ExternalId": "vendor-12345"
  }
}

*/


# EC2 cannot attach IAM role directly.
resource "aws_iam_instance_profile" "ec2_profile" {
  role = aws_iam_role.ec2_role.name
}

/*
S3 Third-Party Access Example

{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:root"
  },
  "Action": "s3:PutObject",
  "Resource": "arn:aws:s3:::my-bucket/*"
}

*/


/*
3️⃣ Conditional Policies

Add IP restriction:

"Condition": {
  "IpAddress": {
    "aws:SourceIp": "10.0.0.0/16"
  }
}

Add MFA requirement:

"Condition": {
  "Bool": {
    "aws:MultiFactorAuthPresent": "true"
  }
}

Very powerful.
*/

# EXAMPLE

variable "vendor_account_id" {
  type        = string
  description = "AWS account ID of vendor"
}

variable "external_id" {
  type        = string
  description = "External ID for secure role assumption"
}

variable "bucket_name" {
  type        = string
  description = "S3 bucket name"
}

resource "aws_s3_bucket" "secure_bucket" {
  bucket = "my-secure-data-bucket"
}

data "aws_iam_policy_document" "vendor_trust_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.vendor_account_id}:root"]
    }

    actions = ["sts:AssumeRole"]

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.external_id] //without this Any principal in vendor account could attempt to assume the role.
    }
  }
}

resource "aws_iam_role" "vendor_role" {
  name               = "VendorS3ReadOnlyRole"
  assume_role_policy = data.aws_iam_policy_document.vendor_trust_policy.json
}

data "aws_iam_policy_document" "vendor_s3_policy" {
  statement {
    sid     = "AllowReadObjects"
    effect  = "Allow"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.secure_bucket.arn}/*"
    ]
  }

  statement {
    sid     = "AllowListBucket"
    effect  = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.secure_bucket.arn
    ]
  }
}

resource "aws_iam_role_policy" "vendor_policy" {
  name   = "VendorS3ReadOnlyPolicy"
  role   = aws_iam_role.vendor_role.id
  policy = data.aws_iam_policy_document.vendor_s3_policy.json
}