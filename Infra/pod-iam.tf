resource "aws_iam_policy" "aurora_policy" {
  name        = "redemption-aurora-policy"
  description = "allow pod to read aurora secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "${module.aurora.cluster_master_user_secret[0].secret_arn}"
      }
    ]
  })
}


data "aws_iam_policy_document" "aurora_identity_trust" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "redemption_app_role" {
  name               = "redemption-aurora-role"
  assume_role_policy = data.aws_iam_policy_document.aurora_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "redemption_app_attach_aurora" {
  role       = aws_iam_role.redemption_app_role.name
  policy_arn = aws_iam_policy.aurora_policy.arn
}

resource "aws_iam_role_policy_attachment" "redemption_app_attach_sqs" {
  role       = aws_iam_role.redemption_app_role.name
  policy_arn = aws_iam_policy.sqs_policy.arn
}

resource "aws_eks_pod_identity_association" "redemption_app" {
  cluster_name    = module.eks.cluster_name
  namespace       = "deduction"
  service_account = "redemption-sa"
  role_arn        = aws_iam_role.redemption_app_role.arn
}