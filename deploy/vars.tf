variable "aws_region" {
  description = "AWS Region to deploy to"
  default = "eu-north-1"
  type    = string
}

variable "lambda_function_name" {
  description = "The name of the feed-fiddler lambda function"
  default     = "feed_fiddler"
  type        = string
}

variable "feeds_bucket_name" {
  description = "The bucket the rss feeds get put in"
  default     = "feed-fiddler"
  type        = string
}

variable "config_bucket_name" {
  description = "The bucket config.yaml is copied to. Will be publically accessible"
  default     = "feed-fiddler-config"
  type        = string
}

variable "feeds_config_file" {
  description = "Path to the config file to upload to the config bucket"
  type        = string
  default = "../feeds.yaml"
}

variable "lambda_function_zipfile" {
  description = "Path to the zipfile created by `make_lambda_package.sh` or similar; uploaded to AWS as the definition of the lambda function"
  type = string
  default = "./lambda_function.zip"
}

variable "lambda_timeout_seconds" {
  description = "For the timeout field on the lambda function. "
  type = number
  default = "90"
}
