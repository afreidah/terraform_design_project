# -----------------------------------------------------------------------------
# DATA SOURCES
# -----------------------------------------------------------------------------

# Current AWS account
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# PARAMETER STORE (for reading Parameter Store values)
# -----------------------------------------------------------------------------

data "aws_ssm_parameter" "db_username" {
  name = "/${var.environment}/database/master_username"

  depends_on = [module.parameter_store]
}

data "aws_ssm_parameter" "db_password" {
  name            = "/${var.environment}/database/master_password"
  with_decryption = true

  depends_on = [module.parameter_store]
}

data "aws_ssm_parameter" "redis_auth_token" {
  name            = "/${var.environment}/redis/auth_token"
  with_decryption = true

  depends_on = [module.parameter_store]
}

data "aws_ssm_parameter" "opensearch_master_password" {
  name            = "/${var.environment}/opensearch/master_password"
  with_decryption = true

  depends_on = [module.parameter_store]
}
