variable "target_aws_access_key" {
  description = "The AWS access key for the target account"
  type        = string
  sensitive   = true
}

variable "target_aws_secret_key" {
  description = "The AWS secret key for the target account"
  type        = string
  sensitive   = true
}

variable "source_aws_access_key" {
  description = "The AWS access key for the source account"
  type        = string
  sensitive   = true
}

variable "source_aws_secret_key" {
  description = "The AWS secret key for the source account"
  type        = string
  sensitive   = true
}

variable "target_account_id" {
  description = "The ID of the target AWS account"
  type        = string

  validation {
    condition     = length(var.target_account_id) == 12
    error_message = "The target_account_id must be exactly 12 characters long."
  }
}

variable "source_account_id" {
  description = "The ID of the source AWS account"
  type        = string

  validation {
    condition     = length(var.source_account_id) == 12
    error_message = "The source_account_id must be exactly 12 characters long."
  }
}

variable "source_dashboard_id" {
  description = "The ID of the source QuickSight dashboard"
  type        = string

  validation {
    condition     = can(regex("^([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})$", var.source_dashboard_id))
    error_message = "The source_dashboard_id must be a valid UUID."
  }
}

variable "target_account_aws_user_name" {
  description = "The AWS user name for the target account"
  type        = string
}

variable "source_aws_region" {
  description = "The AWS region for the source account"
  type        = string
}

variable "target_aws_region" {
  description = "The AWS region for the target account"
  type        = string
}