locals {
  aws_profile = "default"
  account_id = data.aws_caller_identity.current.account_id
}

###############################################################################
# PROVIDER
###############################################################################

provider "aws" {
  region = "${var.aws_region}"
  profile = local.aws_profile
}

###############################################################################
# KMS
###############################################################################

resource "aws_kms_key" "secret_key" {
  description  = "KMS key for encrypting/decrypting passwords from config files"
}

###############################################################################
# LAMBDA
###############################################################################

resource "aws_lambda_function" "lambda_python" {
  filename      = "../files/lambda_python.zip"
  function_name = "${var.function_name}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "${var.function_name}.lambda_handler"
  runtime       = "${var.python_runtime}"

}

resource "aws_lambda_permission" "allow_api" {
  statement_id  = "AllowAPIgatewayInvokation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_python.function_name
  principal     = "apigateway.amazonaws.com"
}

###############################################################################
# API
###############################################################################

resource "aws_api_gateway_rest_api" "secrets_api" {
 name = "${var.api_name}"
 binary_media_types = ["*/*"]
}

resource "aws_api_gateway_method" "secrets_api_method" {
  rest_api_id   = "${aws_api_gateway_rest_api.secrets_api.id}"
  resource_id   = "${aws_api_gateway_rest_api.secrets_api.root_resource_id}"
  http_method   = "${var.http_method}"
  authorization = "NONE"

  request_parameters = {
    "method.request.header.Accept" = true,
    "method.request.header.Content-Type" = true
   }

  depends_on = [aws_api_gateway_rest_api.secrets_api]
}

resource "aws_api_gateway_integration" "secrets_api_method_integration" {
  rest_api_id   = "${aws_api_gateway_rest_api.secrets_api.id}"
  resource_id   = "${aws_api_gateway_rest_api.secrets_api.root_resource_id}"
  http_method   = "${aws_api_gateway_method.secrets_api_method.http_method}"
  type          = "AWS"
  uri           =  aws_lambda_function.lambda_python.invoke_arn

  integration_http_method = "${var.http_method}"
  passthrough_behavior = "WHEN_NO_TEMPLATES"
  request_templates    = {
    "application/octet-stream" = <<EOF
    {
    "data": "$input.body"
    }
    EOF
  }
  depends_on = [aws_api_gateway_method.secrets_api_method]
}

resource "aws_api_gateway_method_response" "secrets_api_response_200" {
  rest_api_id     = "${aws_api_gateway_rest_api.secrets_api.id}"
  resource_id     = "${aws_api_gateway_rest_api.secrets_api.root_resource_id}"
  http_method     = aws_api_gateway_method.secrets_api_method.http_method
  status_code     = "200"
  response_models = { "application/json" = "Empty" }
  depends_on      = [aws_api_gateway_integration.secrets_api_method_integration]
}

resource "aws_api_gateway_integration_response" "secrets_api_integration_response" {
  rest_api_id = "${aws_api_gateway_rest_api.secrets_api.id}"
  resource_id = "${aws_api_gateway_rest_api.secrets_api.root_resource_id}"
  http_method = aws_api_gateway_method.secrets_api_method.http_method
  status_code = aws_api_gateway_method_response.secrets_api_response_200.status_code
  depends_on  = [aws_api_gateway_method_response.secrets_api_response_200]
}

resource "aws_api_gateway_deployment" "secrets_api_deployment" {
  rest_api_id = "${aws_api_gateway_rest_api.secrets_api.id}"
  stage_name = "${var.stage_name}"

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [data.aws_iam_policy_document.lambda_key_and_invoke_policy,aws_lambda_permission.allow_api]
}

###############################################################################
# IAM
###############################################################################

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"
  assume_role_policy  = data.aws_iam_policy_document.instance_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_role_policies" {
  role       = aws_iam_role.lambda_role.name
  count      = "${length(var.iam_policy_arn)}"
  policy_arn = "${var.iam_policy_arn[count.index]}"
}

data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com","apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "permission_to_lambda" {
  name   = "permission_to_lambda"
  role   = "${aws_iam_role.lambda_role.id}"
  policy = "${data.aws_iam_policy_document.lambda_key_and_invoke_policy.json}"
}

data "aws_iam_policy_document" "lambda_key_and_invoke_policy" {
  statement {
    effect = "Allow"
    actions = ["lambda:InvokeFunction","kms:Decrypt"]
    resources = ["arn:aws:lambda:${var.aws_region}:${local.account_id}:function:lambda_python","arn:aws:kms:${var.aws_region}:${local.account_id}:key/${aws_kms_key.secret_key.key_id}"]
  }
  depends_on = [aws_api_gateway_integration_response.secrets_api_integration_response]
}
