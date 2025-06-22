# Publicly accessible S3 bucket via policy
resource "aws_s3_bucket" "feeds_bucket" {
  bucket = var.feeds_bucket_name
}

resource "aws_s3_bucket_policy" "feeds_bucket_policy" {
  bucket = aws_s3_bucket.feeds_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowPublicRead",
        Effect    = "Allow",
        Principal = "*",
        Action    = [
          "s3:GetObject",
          "s3:GetBucketLocation"
        ]
        Resource  = [
          "${aws_s3_bucket.feeds_bucket.arn}/*",
          "${aws_s3_bucket.feeds_bucket.arn}"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "feeds_bucket_access" {
  bucket                  = aws_s3_bucket.feeds_bucket.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

# Private config bucket restricted to Lambda function
resource "aws_s3_bucket" "config_bucket" {
  bucket = var.config_bucket_name
}

resource "aws_s3_bucket_policy" "config_bucket_policy" {
  bucket = aws_s3_bucket.config_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "AllowLambdaAccess",
        Effect   = "Allow",
        Principal = {
          AWS = aws_lambda_function.feed_fiddler_function.role
        },
        Action   = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = "${aws_s3_bucket.config_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "config_bucket_access" {
  bucket                  = aws_s3_bucket.config_bucket.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Upload config file to private bucket
resource "aws_s3_object" "feeds_config_upload" {
  bucket = aws_s3_bucket.config_bucket.id
  key    = "feeds-config.json"
  source = var.feeds_config_file
  etag   = filemd5(var.feeds_config_file)
}

# Output public URL for feeds bucket
output "feeds_bucket_public_url" {
  description = "Public HTTP URL of the feeds bucket"
  value       = "https://${aws_s3_bucket.feeds_bucket.bucket}.s3.amazonaws.com/"
}
