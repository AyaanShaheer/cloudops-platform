terraform {
  backend "s3" {
    bucket         = "cloudops-platform-tfstate"   # change to your unique bucket
    key            = "global/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cloudops-platform-tf-locks"
    encrypt        = true
  }
}