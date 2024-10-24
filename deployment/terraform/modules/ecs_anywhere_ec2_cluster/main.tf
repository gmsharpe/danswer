provider "aws" {
  region = "us-west-1"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_availability_zones" "available" {}




