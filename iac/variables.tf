###############################################################################
# AWS
###############################################################################

variable "aws_region" {
  default = "eu-west-1"
}
variable "credentials_file" {
  default = "../files/credentials.json"
}

variable "encrypted_file" {
  default = "../files/encrypted"
}
###############################################################################
# IAM
###############################################################################

variable "iam_policy_arn" {
  description = "IAM Policy to be attached to role"
  type = list(string)
  default = ["arn:aws:iam::aws:policy/AWSLambdaExecute", "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole","arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole","arn:aws:iam::aws:policy/SecretsManagerReadWrite","arn:aws:iam::aws:policy/service-role/AWSLambdaRole"]
}

###############################################################################
# API
###############################################################################

variable "api_name" {
  default = "secrets_api"
}

variable "http_method" {
  default = "POST"
}

variable "stage_name" {
  default = "v1"
}

###############################################################################
# LAMBDA
###############################################################################

variable "function_name" {
  default = "lambda_python"
}

variable "python_runtime" {
  default = "python3.9"
}

###############################################################################
# DATA BLOCK
###############################################################################

data "aws_caller_identity" "current" {}
