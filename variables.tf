variable "global_name" {
  description = "Global name of this project/account with environment"
  type        = string
  default     = ""
}

variable "global_project" {
  description = "Global name of this project (without environment)"
  type        = string
  default     = ""
}

variable "local_environment" {
  description = "Local name of this environment (eg, prod, stage, dev, feature1)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = map(string)
  default     = {}
}

variable "scan_trigger_schedule_expression" {
  description = "Scan trigger exression, can be in crontab format"
  type        = string
  default     = "0 1 * * ? *"
}

variable "slack_channel" {
  description = "Slack channel to send scan notification to."
  type        = string
}

variable "slack_username" {
  description = "Slack username to be displayed with the message."
  type        = string
  default     = "ecr-scan"
}

variable "slack_emoji" {
  description = "Slack icon to be displayed with the message."
  type        = string
  default     = ":aws:"
}

variable "slack_webhook_url" {
  description = "Slack webhook to send the message to."
  type        = string
}

variable "risk_levels" {
  description = "Risk level to be reported on slack, available options: HIGH, MEDIUM, INFORMATIONAL, LOW, CRITICAL, UNDEFINED"
  type        = string
  default    = "HIGH, CRITICAL"
}
