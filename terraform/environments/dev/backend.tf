terraform {
    backend "s3" {
        bucket = "cloudops-platform-tfstate-f0dd4931"
        key = "dev/terraform.tfstate"
        region = "us-east-1"
        dynamodb_table = "cloudops-platform-tf-locks"
        encrypt = true
    }
}
