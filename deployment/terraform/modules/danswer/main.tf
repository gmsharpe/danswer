
variable "cluster_arn" { }

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}