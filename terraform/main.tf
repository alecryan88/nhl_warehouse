# Configure the AWS Provider
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.26.0"
    }
    snowflake = {
      source = "Snowflake-Labs/snowflake"
      version = "0.76.0"
    }
  }
}