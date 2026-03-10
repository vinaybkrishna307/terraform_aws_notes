variable "vpc_id" {
  default = ""
}

resource "aws_security_group" "web" {
  name   = "web-sg"
  vpc_id = var.vpc_id

  ingress {                       //traffic coming to resource
    from_port   = 80              //allow other resources to connect to my app using 80 port
    to_port     = 80              //ending port allowed says only port 80 is allowed
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   //who can talk to me or which cidr block range can talk to me like office ip or vpc ip
    self = true                   //Allows instances in same SG to communicate.
  }
}



# Prefix List
# office IP changes:
# Dry concept
# You must update 20 places.
resource "aws_ec2_managed_prefix_list" "corp_office" {
  name           = "corp-office"
  address_family = "IPv4"
  max_entries    = 5

  entry {
    cidr        = "203.10.10.0/24"
    description = "Head Office"
  }

  entry {
    cidr        = "203.20.20.0/24"
    description = "Branch Office"
  }
}

resource "aws_security_group_rule" "allow_office_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.web.id
  prefix_list_ids   = [aws_ec2_managed_prefix_list.corp_office.id]
}//Only office networks can SSH.


# Better alternate cause changing CIDR block doesnt destroy security grp but only group_rule
resource "aws_security_group" "app" {
  name   = "app-sg"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "app_https_out" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.app.id
  cidr_blocks       = ["0.0.0.0/0"]
}

//stateful virtual firewall that controls inbound and outbound traffic
//Control which resources can talk to which.
//network level segmentation

//common ports
//80->http
//https->443

//sg to sg re -> security_groups = [aws_security_group.app_sg.id] only instance belong to app_sg can access that security grp

//what not to do
# 0.0.0.0/0 on port 22 unless temporary
#
# 0.0.0.0/0 on database ransomeware attack
#
# CIRDs range for internal traffic
# cidr_blocks = ["10.0.0.0/16"]
# from_port = 0
# to_port   = 65535 ->dont give range only allow specific ports

# Think of SG as:
#
# “Who is allowed to knock on this door?”
#
# Think of IAM as:
#
# “If they enter, what are they allowed to do?”
#
# Both must be tight.
# EC2 Instance
# ┌─────────────────────────┐
# │        Linux OS         │
# │                         │
# │  Port 80  → Web App     │
# │  Port 22  → SSH         │
# │  Port 3000 → Node App   │
# │  Port 5432 → Postgres   │
# └─────────────────────────┘

# EC2 = Apartment Building
#
# IP Address = Building address
#
# Port = Apartment number
#
# App = Person living in apartment

# EC2 only needs S3 use S3 prefix list Or better → Use VPC Endpoint