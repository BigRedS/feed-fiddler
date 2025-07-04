provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      repo = "https://github.com/BigRedS/feed-fiddler"
    }
  }
}

variable "feeds_bucket" {
  default = "feed-fiddler-feeds"
  description = "Name of the public feeds bucket"
  type        = string
}

variable "config_bucket" {
  default = "feed-fiddler-config"
  description = "Name of the private config bucket"
  type        = string
}

resource "aws_iam_policy_attachment" "lambda_logs" {
  name       = "feed_fiddler_lambda_logs_attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "feed_fiddler_function" {
  function_name    = var.lambda_function_name
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_role.arn
  filename         = var.lambda_function_zipfile
  source_code_hash = filebase64sha256(var.lambda_function_zipfile)
  timeout          = var.lambda_timeout_seconds

  environment {
    variables = {
#      CONFIG_FILE_URL = "https://${aws_s3_bucket.config_bucket.bucket}.s3.amazonaws.com/${aws_s3_object.feeds_config_upload.key}"
      FF_CONFIG_FILE_S3_BUCKET = aws_s3_bucket.config_bucket.bucket,
      FF_CONFIG_FILE_S3_OBJECT_NAME = aws_s3_object.feeds_config_upload.key,
      FF_IS_LAMBDA = "yes"
    }
  }
}

resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "feed_fiddler_daily_lambda_trigger"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule = aws_cloudwatch_event_rule.daily_trigger.name
  arn  = aws_lambda_function.feed_fiddler_function.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.feed_fiddler_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}

output "lambda_arn" {
  value = aws_lambda_function.feed_fiddler_function.arn
}

# Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "lambda_s3_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach basic execution policy for logging
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3_access" {
  name = "lambda-s3-access"
  #role = aws_lambda_function.feed_fiddler_function.role.name
  role = aws_iam_role.lambda_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetBucketLocation"
        ],
        Resource = [
          "${aws_s3_bucket.config_bucket.arn}/*",
          "${aws_s3_bucket.config_bucket.arn}",
          "${aws_s3_bucket.feeds_bucket.arn}/*",
          "${aws_s3_bucket.feeds_bucket.arn}"
        ]
      }
    ]
  })
}
