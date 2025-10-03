terraform {
  backend "s3" {
    bucket         = "microservices-eks-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "microservices-eks-terraform-locks"
    encrypt        = true
  }
}