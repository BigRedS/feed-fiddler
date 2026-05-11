locals {
  use_custom_domain = var.web_domain != ""
}

resource "aws_s3_bucket" "web_bucket" {
  bucket = var.web_bucket_name
}

resource "aws_s3_bucket_public_access_block" "web_bucket_access" {
  bucket                  = aws_s3_bucket.web_bucket.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "web_oac" {
  name                              = "${var.web_bucket_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ACM certificate — only created when web_domain is set.
# CloudFront requires certificates to be in us-east-1 regardless of where
# everything else lives, hence the provider alias.
resource "aws_acm_certificate" "web" {
  count             = local.use_custom_domain ? 1 : 0
  provider          = aws.us_east_1
  domain_name       = var.web_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Prints the validation CNAME to the terminal so it can be added to DNS
# while the apply is blocked waiting for issuance.
resource "null_resource" "acm_validation_hint" {
  count = local.use_custom_domain ? 1 : 0

  triggers = {
    cert_arn = aws_acm_certificate.web[0].arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo ""
      echo "==> Certificate created. Add this CNAME record in your DNS provider:"
      echo "    Name:  ${tolist(aws_acm_certificate.web[0].domain_validation_options)[0].resource_record_name}"
      echo "    Value: ${tolist(aws_acm_certificate.web[0].domain_validation_options)[0].resource_record_value}"
      echo ""
      echo "    Waiting for validation (usually a few minutes after the record propagates)..."
    EOT
  }
}

resource "aws_acm_certificate_validation" "web" {
  count           = local.use_custom_domain ? 1 : 0
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.web[0].arn

  depends_on = [null_resource.acm_validation_hint]
}

resource "aws_cloudfront_distribution" "web" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  aliases             = local.use_custom_domain ? [var.web_domain] : []

  origin {
    domain_name              = aws_s3_bucket.web_bucket.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.web_bucket.bucket
    origin_access_control_id = aws_cloudfront_origin_access_control.web_oac.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.web_bucket.bucket
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = local.use_custom_domain ? false : true
    acm_certificate_arn            = local.use_custom_domain ? aws_acm_certificate_validation.web[0].certificate_arn : null
    ssl_support_method             = local.use_custom_domain ? "sni-only" : null
    minimum_protocol_version       = local.use_custom_domain ? "TLSv1.2_2021" : null
  }
}

resource "aws_s3_bucket_policy" "web_bucket_policy" {
  bucket = aws_s3_bucket.web_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFront"
      Effect = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.web_bucket.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.web.arn
        }
      }
    }]
  })
}

resource "aws_s3_object" "web_index" {
  bucket       = aws_s3_bucket.web_bucket.id
  key          = "index.html"
  source       = "../web/index.html"
  content_type = "text/html"
  etag         = filemd5("../web/index.html")
}

resource "aws_s3_object" "web_icon" {
  bucket       = aws_s3_bucket.web_bucket.id
  key          = "icon.png"
  source       = "../web/icon.png"
  content_type = "image/png"
  etag         = filemd5("../web/icon.png")
}

output "web_url" {
  description = "URL for the web UI"
  value       = local.use_custom_domain ? "https://${var.web_domain}" : "https://${aws_cloudfront_distribution.web.domain_name}"
}

output "web_cloudfront_cname_target" {
  description = "Point your subdomain CNAME at this value in your DNS provider"
  value       = local.use_custom_domain ? aws_cloudfront_distribution.web.domain_name : null
}

output "web_cloudfront_distribution_id" {
  description = "CloudFront distribution ID (used for cache invalidations)"
  value       = aws_cloudfront_distribution.web.id
}
