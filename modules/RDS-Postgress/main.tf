variable "private_subnet_ids" {}
variable "vpc_id" {}
variable "app_sg_id" {}
variable "kms_key_id" {}



resource "aws_db_subnet_group" "this" {
  name       = "prod-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "prod-db-subnet-group"
  }
}

resource "aws_security_group" "rds_sg" {
  name   = "prod-rds-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.app_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


/*
Debugging , Security monitoring , Capacity planning
These logs typically go to cloudwatch if enabled in RDS
*/
resource "aws_db_parameter_group" "this" {      //configure template for db engine
  name   = "prod-postgres-params"
  family = "postgres15"

  parameter {
    name  = "log_connections"     //logs every successful connection to the database
    value = "1"
  }

  parameter {
    name  = "log_disconnections"  //logs when clients disconnect->shows session duration, number of transactions
    value = "1"
  }
}


//optional engine-level capabilities (replication plugins, security integrations, etc.)
/*resource "aws_db_option_group" "this" {
  name                 = "prod-postgres-options"
  engine_name          = "postgres"
  major_engine_version = "15"
}*/


resource "random_password" "db" {       //Generates a 20-character password
  length  = 20
  special = true
}

resource "aws_secretsmanager_secret_version" "db" {       //stores username and pass in JSON
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.db.result
  })
}

/*
{
  "username": "dbadmin",
  "password": "generated-random-password"
}
*/

resource "aws_secretsmanager_secret" "db" {       //creates a secret container or vault but does not store anything yet + automatic encryption with KMS
  name = "prod-postgres-secret"
}

/*
Create password -> convert to JSON format -> place it in secret container
*/


resource "aws_db_instance" "this" {
  identifier              = "prod-postgres-db"              //db instance name
  engine                  = "postgres"                      //create postgres RDS instance
  engine_version          = "15"                            //engine version
  instance_class          = "db.t3.medium"                  //burstable instance but not for db

  //storage config
  allocated_storage       = 20                              //initial
  max_allocated_storage   = 100                             //max
  storage_type            = "gp3"                           //storage type->gp3 predictable and cheaper
  storage_encrypted       = true
  kms_key_id              = var.kms_key_id

  //networking
  db_subnet_group_name    = aws_db_subnet_group.this.name   //places db inside private subnet controlled by RDS security group
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]

  multi_az                = true                            //high availability
  publicly_accessible     = false                           //no public ip

  //backup -> backup are incremental + continuous WAL(write-ahead logging) archiving
  backup_retention_period = 7                               //keeps automated backup for seven days which allow point-in-time recovery (PITR) ideally 14-35 days
  backup_window           = "02:00-03:00"                   //daily time window fof automated snapshots backup and backup related I/O operations in this time DB is available
  //if today is March 10 -> You can restore the DB to any second between March 3 and March 10.

  //custom config->Your custom logging parameter group
  parameter_group_name    = aws_db_parameter_group.this.name
  # option_group_name       = aws_db_option_group.this.name

  //Credentials via Secrets Manager
  username = jsondecode(aws_secretsmanager_secret_version.db.secret_string)["username"]
  password = jsondecode(aws_secretsmanager_secret_version.db.secret_string)["password"]

  //Deletion Protection & Snapshot
  skip_final_snapshot     = false                             //Prevents accidental deletion.
  deletion_protection     = true                              //AWS forces a final snapshot.

  //Enables query-level performance monitoring
  performance_insights_enabled = true                         //top queries,wait events,cpu bottlenecks,lock contention

  //cloudwatch
  enabled_cloudwatch_logs_exports = ["postgresql"]            //postgres log -> cloudwatch logs -> log group postgresql
}

//auto deletes logs every 30 days and no infinite accumulation
resource "aws_cloudwatch_log_group" "rds_postgres" {
  name              = "/aws/rds/instance/prod-postgres-db/postgresql"
  retention_in_days = 30
}

/*

RTO (Recovery Time Objective): How quickly systems must be restored after a failure to avoid,
for example, high costs or operational issues.

RPO (Recovery Point Objective): How far back in time data can be lost
(e.g., 4 hours of data) without causing significant harm.

Focus: RTO focuses on the speed of recovery, while RPO focuses on the amount of data loss.

Purpose: RTO drives the recovery strategy, while RPO drives backup frequency.

*/


################################################
/*So, while creating a KMS key for RDS, we will write trust policy in RDS
 saying RDS can make use of or have access to KMS keys. And we will also create another
 policy saying that I will trust RDS with this KMS key.*/
//RDS snapshot export requires SSE-KMS.
resource "aws_kms_key" "rds_export_key" {
  description             = "KMS key for RDS snapshot export to S3"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_iam_role" "rds_export_role" {
  name = "rds-snapshot-export-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "rds.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}


//Restrict to Specific S3 Prefix
/*
Bucket name: my-backup-bucket
Allowed prefix: rds-exports/
*/
resource "aws_iam_policy" "rds_export_policy" {
  name = "rds-export-to-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [

      # Allow writing only to specific prefix
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:AbortMultipartUpload"
        ],
        Resource = "arn:aws:s3:::my-backup-bucket/rds-exports/*"
      },

      # Allow listing bucket (restricted)
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket"
        ],
        Resource = "arn:aws:s3:::my-backup-bucket",
        Condition = {
          StringLike = {
            "s3:prefix" = "rds-exports/*"
          }
        }
      },

      # Allow using KMS key
      {
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ],
        Resource = aws_kms_key.rds_export_key.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_rds_export" {
  role       = aws_iam_role.rds_export_role.name
  policy_arn = aws_iam_policy.rds_export_policy.arn
}


//Bucket Policy – Enforce Encryption + Restrict Role
/*
{
  "Version": "2012-10-17",
  "Statement": [

    {
      "Sid": "AllowRDSExportRoleOnly",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/rds-snapshot-export-role"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::my-backup-bucket/rds-exports/*"
    },

    {
      "Sid": "DenyUnEncryptedUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::my-backup-bucket/rds-exports/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    }
  ]
}
*/

resource "aws_kms_key_policy" "rds_kms_policy" {
  key_id = aws_kms_key.rds_export_key.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid = "AllowRDSService",
        Effect = "Allow",
        Principal = {
          Service = "rds.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ],
        Resource = "*"
      }
    ]
  })
}//forget this → export fails.

/*

aws rds start-export-task \
  --export-task-identifier my-export-task \
  --source-arn arn:aws:rds:region:account-id:snapshot:snapshot-id \
  --s3-bucket-name my-backup-bucket \
  --iam-role-arn arn:aws:iam::123456789012:role/rds-snapshot-export-role \
  --kms-key-id arn:aws:kms:region:account-id:key/key-id

*/