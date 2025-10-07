#!/bin/bash
# This script sets up the S3 bucket and DynamoDB table for Terraform remote state management.

set -e  # Exit on any error

BUCKET_NAME="microservices-eks-terraform-states"
TABLE_NAME="microservices-eks-terraform-locks"
REGION="us-east-1"

echo "Creating S3 bucket: $BUCKET_NAME"
if aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION"; then
  echo "✓ S3 bucket created successfully"
else
  echo "⚠️ S3 bucket creation failed or bucket already exists"
fi

echo "Enabling S3 bucket versioning"
if aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled; then
  echo "✓ S3 bucket versioning enabled"
else
  echo "❌ Failed to enable S3 bucket versioning"
  exit 1
fi

echo "Configuring S3 bucket encryption"
if aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'; then
  echo "✓ S3 bucket encryption configured"
else
  echo "❌ Failed to configure S3 bucket encryption"
  exit 1
fi

echo "Creating DynamoDB table: $TABLE_NAME"
if aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --billing-mode PAY_PER_REQUEST \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --tags Key=Name,Value="$TABLE_NAME" \
         Key=Environment,Value=shared \
         Key=Purpose,Value=terraform-state-locking; then
  echo "✓ DynamoDB table created successfully"
else
  echo "⚠️ DynamoDB table creation failed or table already exists"
fi

echo "✅ S3 bucket and DynamoDB table setup completed successfully."

echo ""
echo "Backend configuration for environments:"
echo "terraform {"
echo "  backend \"s3\" {"
echo "    bucket         = \"$BUCKET_NAME\""
echo "    key            = \"<environment>/terraform.tfstate\"  # dev/staging/prod"
echo "    region         = \"$REGION\""
echo "    dynamodb_table = \"$TABLE_NAME\""
echo "    encrypt        = true"
echo "  }"
echo "}"
echo ""
echo "Note: For us-east-1 region, --create-bucket-configuration is omitted to avoid AWS errors."
