resource "random_string" "lambda_postfix_generator" {
  length  = 16
  upper   = true
  lower   = true
  number  = true
  special = false
}

resource "aws_iam_role" "lambda_main" {
  name               = "${var.name_prefix}-lambda-role-${random_string.lambda_postfix_generator.result}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "lambda_main" {
  name   = "${var.name_prefix}-lambda-policy-${random_string.lambda_postfix_generator.result}"
  role   = aws_iam_role.lambda_main.name
  policy = var.policy
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"

      identifiers = [
        "lambda.amazonaws.com",
      ]
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = var.log_retention_in_days
}

data "archive_file" "dotfiles" {

  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${var.source_dir}/deployment_package.zip"
}

resource "aws_lambda_function" "lambda" {
  function_name = "${var.name_prefix}-${random_string.lambda_postfix_generator.result}"
  filename      = data.archive_file.dotfiles.output_path

  environment {
    variables = var.environment
  }

  source_code_hash = data.archive_file.dotfiles.output_base64sha256

  tags = var.tags

  handler = var.handler
  runtime = var.runtime

  timeout = var.timeout

  role = aws_iam_role.lambda_main.arn

  lifecycle {
    ignore_changes = [
      //      filename,
      last_modified,
    ]
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }
}
