resource "aws_sqs_queue" "redemption_dlq" {
  name = "redemption-deduction-dlq"
  sqs_managed_sse_enabled = true 
  message_retention_seconds = 60 * 60 * 24 * 7 # 60s * 60m * 24h * 7d
}

resource "aws_sqs_queue" "redemption_queue" {
  name = "redemption-deduction-queue"

  visibility_timeout_seconds = 30
  message_retention_seconds  = 60 * 60 * 24 * 7 # 60s * 60m * 24h * 7d
  sqs_managed_sse_enabled = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.redemption_dlq.arn
    maxReceiveCount     = 4
  })
}

