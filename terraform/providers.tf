provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key

}

provider "snowflake" {
  // required
  account  = var.snowflake_account
  user = var.snowflake_user
  password = var.snowflake_password
  region   = var.snowflake_region
  role     = "ACCOUNTADMIN"

}