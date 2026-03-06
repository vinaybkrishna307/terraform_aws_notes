/*EKS Pods
↓
VPC Endpoint (Private IP inside VPC)
↓
AWS Service (via AWS backbone network)*/

variable "vpc_id" {}
variable "private_route_table_ids" {}


resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.ap-south-1.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = var.private_route_table_ids

  policy = data.aws_iam_policy_document.s3_endpoint.json
}

data "aws_iam_policy_document" "s3_endpoint" {
  statement {
    actions   = ["s3:*"]
    resources = [
      "arn:aws:s3:::my-prod-bucket",
      "arn:aws:s3:::my-prod-bucket/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}


/*//STS endpoint

service_name = "com.amazonaws.ap-south-1.sts"
If STS endpoint is missing: IRSA fails in private cluster.

*/


/*//CloudWatch Logs endpoint

service_name = "com.amazonaws.ap-south-1.logs"
CloudWatch Logs Endpoint

*/


/*
| Use Case              | Endpoint Used      |
| --------------------- | ------------------ |
| Terraform state in S3 | S3                 |
| EKS pulling images    | ECR                |
| IRSA                  | STS                |
| App logs              | CloudWatch         |
| Patch EC2             | SSM                |
| Retrieve secrets      | Secrets Manager    |
| Lambda inside VPC     | Depends on service |
*/


/*
Tips
Use Endpoint Policies
Restrict:
  Only specific IAM roles
  Only specific buckets
  Only specific actions

Use Separate Security Group for Endpoints
  Only allow port 443
  Restrict to VPC CIDR
  No 0.0.0.0/0

Use Private DNS
  For Interface Endpoints:
  private_dns_enabled = true
  So:
  ecr.amazonaws.com
  resolves to private IP.

Enable Flow Logs
  Monitor traffic:
  To detect misuse
  To detect data exfiltration
*/