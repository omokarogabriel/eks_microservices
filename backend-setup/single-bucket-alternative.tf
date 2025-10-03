# Alternative: Single bucket with environment prefixes
resource "aws_s3_bucket" "terraform_state" {
  bucket = "microservices-eks-terraform-state"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "microservices-eks-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "microservices-eks-terraform-locks"
    Environment = "shared"
    Purpose     = "terraform-state-locking"
  }
}

# Backend configs would use:
# key = "dev/terraform.tfstate"
# key = "staging/terraform.tfstate" 
# key = "prod/terraform.tfstate"