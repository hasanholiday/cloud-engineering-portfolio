data "aws_caller_identity" "me" {}

locals {
  name = "ai-assistant"
}

# ---------- Encryption ----------
resource "aws_kms_key" "app" {
  description         = "${local.name} data key"
  enable_key_rotation = true
}

# ---------- Documents and index (private, encrypted, versioned) ----------
resource "aws_s3_bucket" "docs" {
  bucket = "${local.name}-docs-${data.aws_caller_identity.me.account_id}"
}

resource "aws_s3_bucket_public_access_block" "docs" {
  bucket                  = aws_s3_bucket.docs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "docs" {
  bucket = aws_s3_bucket.docs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.app.arn
    }
  }
}

# ---------- Tickets the agent may open ----------
resource "aws_dynamodb_table" "tickets" {
  name         = "${local.name}-tickets"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.app.arn
  }
  point_in_time_recovery { enabled = true }
}

# ---------- Permissions: one role per function, only what it needs ----------
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ask" {
  name               = "${local.name}-ask"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role" "ingest" {
  name               = "${local.name}-ingest"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "ask" {
  statement {
    sid       = "ReadIndexOnly"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.docs.arn}/index/index.json"]
  }
  statement {
    sid       = "UseKey"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.app.arn]
  }
  statement {
    sid     = "InvokeOnlyChosenModels"
    actions = ["bedrock:InvokeModel"]
    resources = concat(
      var.gen_model_arns,
      ["arn:aws:bedrock:${var.region}::foundation-model/${var.embed_model_id}"]
    )
  }
  statement {
    sid       = "OpenTicketsOnly"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.tickets.arn]
  }
  statement {
    sid       = "TicketKey"
    actions   = ["kms:GenerateDataKey", "kms:Encrypt"]
    resources = [aws_kms_key.app.arn]
  }
}

resource "aws_iam_role_policy" "ask" {
  role   = aws_iam_role.ask.id
  policy = data.aws_iam_policy_document.ask.json
}

data "aws_iam_policy_document" "ingest" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.docs.arn]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.docs.arn}/docs/*"]
  }
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.docs.arn}/index/*"]
  }
  statement {
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.app.arn]
  }
  statement {
    actions   = ["bedrock:InvokeModel"]
    resources = ["arn:aws:bedrock:${var.region}::foundation-model/${var.embed_model_id}"]
  }
}

resource "aws_iam_role_policy" "ingest" {
  role   = aws_iam_role.ingest.id
  policy = data.aws_iam_policy_document.ingest.json
}

resource "aws_iam_role_policy_attachment" "ask_logs" {
  role       = aws_iam_role.ask.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "ingest_logs" {
  role       = aws_iam_role.ingest.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ---------- Functions ----------
data "archive_file" "src" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/build/src.zip"
  excludes    = ["__pycache__"]
}

resource "aws_cloudwatch_log_group" "ask" {
  name              = "/aws/lambda/${local.name}-ask"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "ingest" {
  name              = "/aws/lambda/${local.name}-ingest"
  retention_in_days = 14
}

resource "aws_lambda_function" "ask" {
  function_name                  = "${local.name}-ask"
  role                           = aws_iam_role.ask.arn
  runtime                        = "python3.12"
  handler                        = "handlers.ask_handler"
  filename                       = data.archive_file.src.output_path
  source_code_hash               = data.archive_file.src.output_base64sha256
  timeout                        = 30
  memory_size                    = 512
  reserved_concurrent_executions = var.ask_reserved_concurrency # -1 = no cap. New accounts often cannot reserve; the API usage plan already limits traffic
  environment {
    variables = {
      DOCS_BUCKET    = aws_s3_bucket.docs.bucket
      GEN_MODEL_ID   = var.gen_model_id
      EMBED_MODEL_ID = var.embed_model_id
      TICKETS_TABLE  = aws_dynamodb_table.tickets.name
    }
  }
  depends_on = [aws_cloudwatch_log_group.ask]
}

resource "aws_lambda_function" "ingest" {
  function_name    = "${local.name}-ingest"
  role             = aws_iam_role.ingest.arn
  runtime          = "python3.12"
  handler          = "handlers.ingest_handler"
  filename         = data.archive_file.src.output_path
  source_code_hash = data.archive_file.src.output_base64sha256
  timeout          = 300
  memory_size      = 512
  environment {
    variables = {
      DOCS_BUCKET    = aws_s3_bucket.docs.bucket
      EMBED_MODEL_ID = var.embed_model_id
    }
  }
  depends_on = [aws_cloudwatch_log_group.ingest]
}

# ---------- API: key required, throttled, daily quota ----------
resource "aws_api_gateway_rest_api" "api" {
  name = local.name
}

resource "aws_api_gateway_resource" "ask" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "ask"
}

resource "aws_api_gateway_method" "ask" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.ask.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "ask" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.ask.id
  http_method             = aws_api_gateway_method.ask.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.ask.invoke_arn
}

resource "aws_lambda_permission" "api" {
  statement_id  = "AllowApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ask.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  triggers    = { redeploy = sha1(jsonencode([aws_api_gateway_method.ask, aws_api_gateway_integration.ask])) }
  lifecycle { create_before_destroy = true }
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.api.id
  stage_name    = "prod"
}

resource "aws_api_gateway_api_key" "team" {
  name = "${local.name}-key"
}

resource "aws_api_gateway_usage_plan" "team" {
  name = "${local.name}-plan"
  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }
  throttle_settings {
    rate_limit  = 5
    burst_limit = 10
  }
  quota_settings {
    limit  = 1000
    period = "DAY"
  }
}

resource "aws_api_gateway_usage_plan_key" "team" {
  key_id        = aws_api_gateway_api_key.team.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.team.id
}

# ---------- Watch it: token metric, alarm, budget ----------
resource "aws_sns_topic" "alerts" {
  name = "${local.name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_log_metric_filter" "tokens" {
  name           = "${local.name}-tokens"
  log_group_name = aws_cloudwatch_log_group.ask.name
  pattern        = "{ $.event = \"usage\" }"
  metric_transformation {
    name      = "TotalTokens"
    namespace = "AiAssistant"
    value     = "$.total_tokens"
  }
}

resource "aws_cloudwatch_metric_alarm" "tokens" {
  alarm_name          = "${local.name}-daily-tokens"
  namespace           = "AiAssistant"
  metric_name         = "TotalTokens"
  statistic           = "Sum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = var.daily_token_alarm
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "${local.name}-errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.ask.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 3
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_budgets_budget" "monthly" {
  name         = "${local.name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}
