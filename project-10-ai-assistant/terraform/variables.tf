variable "region" {
  type    = string
  default = "us-east-1"
}
variable "gen_model_id" {
  type        = string
  description = "Bedrock model ID or inference profile ID you have enabled in your account. No default on purpose: model names change, pick one in the Bedrock console."
}
variable "gen_model_arns" {
  type        = list(string)
  description = "ARNs the answer function may invoke (the model, and its inference profile if you use one). Least privilege: nothing else."
}
variable "embed_model_id" {
  type    = string
  default = "amazon.titan-embed-text-v2:0"
}
variable "alert_email" {
  type        = string
  description = "Where cost and usage alarms are sent."
}
variable "monthly_budget_usd" {
  type    = number
  default = 20
}
variable "daily_token_alarm" {
  type    = number
  default = 200000
}
variable "ask_reserved_concurrency" {
  type        = number
  default     = -1
  description = "Reserve Lambda concurrency for the answer function to cap cost. Leave -1 on new accounts (they usually keep a minimum of 10 unreserved)."
}
