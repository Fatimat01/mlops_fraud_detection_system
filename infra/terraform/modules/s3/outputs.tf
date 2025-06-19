
output "model_artifacts_bucket_name" {
  description = "Name of the model artifacts bucket"
  value       = aws_s3_bucket.model_artifacts.id
}

output "model_artifacts_bucket_arn" {
  description = "ARN of the model artifacts bucket"
  value       = aws_s3_bucket.model_artifacts.arn
}

## object uri
output "model_artifacts_bucket_object_uri" {
  description = "S3 URI for the model artifacts bucket"
  value       = "s3://${aws_s3_bucket.model_artifacts.id}/model/model.tar.gz"
}