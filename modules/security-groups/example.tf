resource "aws_instance" "app_server" {
  ami           = "ami-xxxx"
  instance_type = "t3.micro"

  subnet_id = aws_subnet.app_subnet.id

  vpc_security_group_ids = [
    aws_security_group.sg_app.id
  ]
}

resource "aws_instance" "db_server" {
  ami           = "ami-xxxx"
  instance_type = "t3.micro"

  subnet_id = aws_subnet.app_subnet.id

  vpc_security_group_ids = [
    aws_security_group.sg_db.id
  ]
}

resource "aws_security_group" "sg_app" {
  name        = "sg-sg_app"
  description = "App tier"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "sg_db" {
  name        = "sg-sg_db"
  description = "DB tier"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group_rule" "app_to_db" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"

  security_group_id        = aws_security_group.sg_db.id
  source_security_group_id = aws_security_group.sg_app.id

  description = "Allow application tier to access database"
}