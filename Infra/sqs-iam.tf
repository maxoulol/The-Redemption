resource "aws_iam_policy" "sqs_policy" {
  name        = "redemption-app-policy"
  description = "Allow app to use DB and SQS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.redemption_queue.arn
      }
    ]
  })
}