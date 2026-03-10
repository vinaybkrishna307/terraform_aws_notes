
# create central routing hub.
resource "aws_ec2_transit_gateway" "this" {
  description = "Main TGW"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  tags = {
    Name = "main-tgw"
  }
}

# Creates a logical connection between VPC and TGW.
/*
Attach using private subnets
One subnet per AZ recommended
*/
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_a" {
  subnet_ids         = aws_subnet.vpc_a_private[*].id
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.vpc_a.id

  tags = {
    Name = "vpc-a-attachment"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_b" {
  subnet_ids         = aws_subnet.vpc_b_private[*].id
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.vpc_b.id

  tags = {
    Name = "vpc-b-attachment"
  }
}


//TGW has its own routing logic separate from VPC route tables.
//Controls how traffic moves between attachments.
resource "aws_ec2_transit_gateway_route_table" "main_rt" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name = "main-tgw-rt"
  }
}


// Traffic won’t know which TGW route table to use.
// Links attachment → route table.
//You tell each VPC connection:
# "Use this rulebook."
resource "aws_ec2_transit_gateway_route_table_association" "vpc_a_assoc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_a.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main_rt.id
}

resource "aws_ec2_transit_gateway_route_table_association" "vpc_b_assoc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_b.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main_rt.id
}


# Automatically adds VPC CIDR into TGW route table.
# 10.0.0.0/16 → VPC-A attachment
# TGW won’t know where that CIDR lives.
# You allow TGW to automatically learn each VPC’s CIDR.
resource "aws_ec2_transit_gateway_route_table_propagation" "vpc_a_propagation" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_a.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main_rt.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "vpc_b_propagation" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_b.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main_rt.id
}


/*
VPC-A (10.0.0.0/16)

VPC-B (10.1.0.0/16)
*/

/*
Step 6 — Update VPC-A Route Table
resource "aws_route" "vpc_a_to_vpc_b" {
  route_table_id         = aws_route_table.vpc_a_private.id
  destination_cidr_block = "10.1.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}
If traffic going to 10.1.0.0/16 → send to TGW.
*/


/*
Step 7 — Update VPC-B Route Table
resource "aws_route" "vpc_b_to_vpc_a" {
  route_table_id         = aws_route_table.vpc_b_private.id
  destination_cidr_block = "10.0.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}
*/