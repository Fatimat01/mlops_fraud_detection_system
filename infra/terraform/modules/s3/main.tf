# modules/s3/main.tf

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_s3_bucket" "model_artifacts" {
  bucket = "${var.project_name}-model-artifacts-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-model-artifacts"
  })
}

resource "aws_s3_bucket_versioning" "model_artifacts" {
  bucket = aws_s3_bucket.model_artifacts.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "model_artifacts" {
  bucket = aws_s3_bucket.model_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "model_artifacts" {
  bucket = aws_s3_bucket.model_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "model_artifact" {
  bucket = aws_s3_bucket.model_artifacts.id
  key    = "model/model.tar.gz"
  source = "../../${path.root}/model/model.tar.gz" # Path to your model artifact
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-model"
    Version = "latest"
  })
}
