terraform {
  backend "s3" {
    bucket         = "fatimat-tf-state"
    key            = "fraud-detection.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "fatimat-tf-state-lock"
  }
}