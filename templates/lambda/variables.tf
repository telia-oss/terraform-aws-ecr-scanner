variable "tags" {
  description = "Map of tags to assign to lambda function"
  type        = map(string)
  default     = {}
}

variable "name_prefix" {
  description = "Name prefix of lambda function"
  type        = string
}

variable "policy" {
  description = "A policy document for the lambda execution role."
  type        = string
}

variable "environment" {
  description = "A map that defines environment variables for the Lambda function."
  type        = map(string)

  default = {
    NA = "NA"
  }
}

variable "runtime" {
  description = "Lambda runtime. Defaults to Go 1.x."
  default     = "go1.x"
  type        = string
}

variable "handler" {
  description = "The function entrypoint in your code."
  default     = "main"
  type        = string
}

variable "timeout" {
  description = "Execution timeout."
  default     = 30
  type        = number
}

variable "subnet_ids" {
  description = "VPC subnets for Lambda"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "SG IDs for Lambda, should at least allow all outbound"
  type        = list(string)
  default     = []
}

variable "log_retention_in_days" {
  description = "Log retention of the lambda function"
  default     = 60
  type        = number
}

variable "source_dir" {
  description = "Path to the directory containing lambda code"
  type        = string
}
