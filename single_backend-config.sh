#!/bin/bash
# This script sets up the S3 bucket and DynamoDB table for Terraform remote state management.

aws s3api create-bucket \
  --bucket microservices-eks-terraform-state \
  --region us-east-1 \
#   --create-bucket-configuration LocationConstraint=us-east-1


# (⚠️ If your region is us-east-1, you should omit --create-bucket-configuration, otherwise AWS will throw an error.)

aws s3api put-bucket-versioning \
  --bucket microservices-eks-terraform-state \
  --versioning-configuration Status=Enabled



aws s3api put-bucket-encryption \
  --bucket microservices-eks-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'


aws dynamodb create-table \
  --table-name microservices-eks-terraform-locks \
  --billing-mode PAY_PER_REQUEST \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --tags Key=Name,Value=microservices-eks-terraform-locks \
         Key=Environment,Value=shared \
         Key=Purpose,Value=terraform-state-locking

echo "S3 bucket and DynamoDB table created successfully."

# terraform {
#   backend "s3" {
#     bucket         = "microservices-eks-terraform-state"
#     key            = "dev/terraform.tfstate"     # change per environment
#     region         = "us-east-1"
#     dynamodb_table = "microservices-eks-terraform-locks"
#     encrypt        = true
#   }
# }
