terraform {
  backend "s3" {                                  //store my state file in s3
    bucket          = "example-bucket"            //name of s3 bucket stored we want to use
    key             = "dev/terraform.tfstate"     //file path in s3 example-bucket->dev->terraform.tfstate
    region          = "ap-south-1"                //region of s3 bucket
    dynamodb_table  = "terrafform-locks"          //prevents corruption and drift -> tf create a lock in dynamodb deletes after apply is finished till then others cannot tf apply
    encrypt         = true                        //server side encryption use kms for production
    # kms_key_id      = "arn:aws:kms:..."         //kms encryption
  }
}
//server side encryption means data is encrypted your data after it receives and decrypts before sending it
// used for team collaboration, state locking, versioning, disaster recovery
//note: https/tls -> encryption in transit -> protects data while moving over network