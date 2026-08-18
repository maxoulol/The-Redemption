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

# role for KEDA
resource "aws_iam_role" "keda_operator_role" {
  name               = "keda-operator-role"
  assume_role_policy = data.aws_iam_policy_document.aurora_identity_trust.json
}

resource "aws_iam_policy" "keda_sqs_policy" {
  name = "keda-sqs-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.redemption_queue.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "keda_attach" {
  role       = aws_iam_role.keda_operator_role.name
  policy_arn = aws_iam_policy.keda_sqs_policy.arn
}

resource "aws_eks_pod_identity_association" "keda_operator" {
  cluster_name    = module.eks.cluster_name
  namespace       = "keda"
  service_account = "keda-operator"
  role_arn        = aws_iam_role.keda_operator_role.arn
}

resource "aws_eks_pod_identity_association" "keda_metrics" {
  cluster_name    = module.eks.cluster_name
  namespace       = "keda"
  service_account = "keda-operator-metrics-apiserver"
  role_arn        = aws_iam_role.keda_operator_role.arn
}