locals {
  config       = yamldecode(file("../config.yml"))
  project_name = local.config.project_name
  schedule = local.config.schedule
  lambda_runtime = local.config.lambda_runtime
  aws_account_id = data.aws_caller_identity.current.account_id
  role_arn = "arn:aws:iam::${local.aws_account_id}:role/${var.environment}-${local.project_name}"
}