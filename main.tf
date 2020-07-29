data "aws_iam_policy_document" "lambda" {
  statement {
    effect = "Allow"

    actions = [
      "ecr:*",
      "cloudwatch:*",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "*"
    ]
  }
}

data "aws_iam_policy_document" "sfn_invoke_lamnda" {
  statement {
    effect = "Allow"

    actions = [
      "lambda:InvokeFunction"
    ]

    resources = [
      module.ecr-scan-notify-lambda.arn,
      module.ecr-scan-trigger-lambda.arn
    ]
  }
}

data "aws_iam_policy_document" "cloudwatch_start_sfn" {
  statement {
    effect = "Allow"

    actions = [
      "states:StartExecution"
    ]

    resources = [
      "*"
    ]
  }
}

module "ecr-scan-trigger-lambda" {
  source = "./templates/lambda"

  policy      = data.aws_iam_policy_document.lambda.json
  name_prefix = "ecr-scan-trigger-${var.local_environment}"

  source_dir = "${path.module}/lambdas_code/scan_trigger"

  handler = "lambda_function.lambda_handler"
  runtime = "python3.6"

  subnet_ids = var.subnet_ids
  security_group_ids = var.security_group_ids


  tags = merge(
    var.tags,
    map("Name", var.global_name),
    map("Project", var.global_project),
    map("Environment", var.local_environment)
  )
}

module "ecr-scan-notify-lambda" {
  source = "./templates/lambda"

  policy      = data.aws_iam_policy_document.lambda.json
  name_prefix = "ecr-scan-notify-${var.local_environment}"

  source_dir = "${path.module}/lambdas_code/scan_notify"

  handler = "lambda_function.lambda_handler"
  runtime = "python3.6"

  subnet_ids = var.subnet_ids
  security_group_ids = var.security_group_ids

  environment = {
    SLACK_CHANNEL     = var.slack_channel
    SLACK_USERNAME    = var.slack_username
    SLACK_EMOJI       = var.slack_emoji
    SLACK_WEBHOOK_URL = var.slack_webhook_url
    RISK_LEVELS       = var.risk_levels

  }

  tags = merge(
    var.tags,
    map("Name", var.global_name),
    map("Project", var.global_project),
    map("Environment", var.local_environment)
  )
}

resource "random_string" "postfix_generator" {
  length  = 6
  upper   = true
  lower   = true
  number  = true
  special = false
}

resource "aws_iam_role" "iam_for_sfn" {
  name = "ecr-scan-stepfunction-role-${random_string.postfix_generator.result}"

  assume_role_policy = data.aws_iam_policy_document.sfn_assume_role_policy_document.json
}

resource "aws_iam_policy" "policy_for_sfn_lambdas" {
  name   = "policy_for_sfn_lambdas"
  policy = data.aws_iam_policy_document.sfn_invoke_lamnda.json
}

resource "aws_iam_policy" "cloudwatch_start_sfn" {
  name   = "cloudwatch_start_sfn"
  policy = data.aws_iam_policy_document.cloudwatch_start_sfn.json
}

resource "aws_iam_role_policy_attachment" "sfn_lambda_perrmissions" {
  role       = aws_iam_role.iam_for_sfn.name
  policy_arn = aws_iam_policy.policy_for_sfn_lambdas.arn
}

resource "aws_iam_role_policy_attachment" "clodwatch_start_sfn" {
  role       = aws_iam_role.iam_for_sfn.name
  policy_arn = aws_iam_policy.cloudwatch_start_sfn.arn
}

// Assume role policy document
data "aws_iam_policy_document" "sfn_assume_role_policy_document" {

  statement {
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"
      identifiers = [
        "states.amazonaws.com",
        "events.amazonaws.com"
      ]
    }
  }
}

resource "aws_sfn_state_machine" "orchestrate_scan_sfn" {
  name     = "ecr-scan-sfn-${var.local_environment}-${random_string.postfix_generator.result}"
  role_arn = aws_iam_role.iam_for_sfn.arn

  definition = <<EOF
{
  "Comment": "SFN to orchastrate ECR vulnerability scanning.",
  "StartAt": "TriggerScan",
  "States": {
    "TriggerScan": {
      "Type": "Task",
      "Resource": "${module.ecr-scan-trigger-lambda.arn}",
      "Next": "Wait"
    },
    "Wait": {
      "Type": "Wait",
      "Seconds": 300,     
      "Next": "Notify"
    },
    "Notify": {
      "Type": "Task",
      "Resource": "${module.ecr-scan-notify-lambda.arn}",         
      "End": true
    }
  }
}
EOF
}


resource "aws_cloudwatch_event_rule" "trigger_scan" {
  name                = "ecr-trigger-scan-rule-${var.local_environment}-${random_string.postfix_generator.result}"
  schedule_expression = "cron(${var.scan_trigger_schedule_expression})"
}

resource "aws_cloudwatch_event_target" "trigger_scan_sfn" {
  rule     = aws_cloudwatch_event_rule.trigger_scan.id
  arn      = aws_sfn_state_machine.orchestrate_scan_sfn.id
  role_arn = aws_iam_role.iam_for_sfn.arn
}

