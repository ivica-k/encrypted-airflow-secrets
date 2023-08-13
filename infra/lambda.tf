data "aws_region" "current" {}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "../functions/kms_encrypt/lambda_function.py"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "this" {
  filename      = data.archive_file.lambda.output_path
  function_name = "${local.name_prefix}-function"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.11"

  layers = [
    "arn:aws:lambda:${data.aws_region.current.name}:017000801446:layer:AWSLambdaPowertoolsPythonV2:41"
  ]

  environment {
    variables = {
      LOG_LEVEL  = lower(var.env) == "prod" ? "INFO" : "DEBUG"
      KMS_KEY_ID = aws_kms_key.this.arn
    }
  }
}

resource "aws_lambda_function_url" "this" {
  function_name      = aws_lambda_function.this.function_name
  authorization_type = "NONE"
}
