resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"    //~65536 ip address are available subnets are created from this->choose non overlapping CIDRs
  enable_dns_support   = true   //Instances cannot resolve domain names like google.com
  enable_dns_hostnames = true   //Allows instances to get DNS hostnames->ip-10-0-1-5.ap-south-1.compute.internal
  tags =
    {
      Name = "example-vpc"      //important for cost collection,identity,org governance,automation
    }
}

//flow logs for vpc

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {     //Flow logs need a destination.
  name              = "/aws/vpc-flow-logs/example-vpc"
  retention_in_days = 30                                  //Retention prevents infinite log growth (cost control)
}

//IAM Role for Flow Logs
//Flow Logs need permission to write logs
resource "aws_iam_role" "flow_logs_role" {
  name = "example-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })
}

//Attach policy:
resource "aws_iam_role_policy_attachment" "flow_logs_attach" {
  role       = aws_iam_role.flow_logs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

//Attach policy:
resource "aws_flow_log" "this" {
  iam_role_arn    = aws_iam_role.flow_logs_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"                                        //All because rejected traffic often shows attack attempts.
  vpc_id          = aws_vpc.this.id
}

//flow logs helps in determining port scanning,sus outbound traffic, data exfiltration, misconfig, Lateral movement (Gains access to one system… then moves sideways inside the network to compromise more systems.)
//for advance features send logs to elk for better analysis, send logs to s3, use athena for quering