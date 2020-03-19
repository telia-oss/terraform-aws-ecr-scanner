# AWS ECR Vulnerability Scaning Terraform module
================================================

The module will trigger vulnerability scanning on all images in account ECR and will report the results to Slack channel.

## Architecture

The module will deploy CloudWatch rule to shcedule the scan, Step Function to orchestrate the lamgdas, and two lambda functions. One for triggering the scan and second to read the results and report the outcame.

## Basic usage

```
module "ecr-regular-scanning" {
  source = "<module path>"

  slack_channel = "<slack_channel_name>"
  slack_webhook_url = "<slack_webhook>"

}
```

You can set the levels of vulnerability, you want to get notified by changing risk_levels variable.

Default value is: "HIGH, CRITICAL"

You can get alarms for the following levels: HIGH, MEDIUM, INFORMATIONAL, LOW, CRITICAL, UNDEFINED.


