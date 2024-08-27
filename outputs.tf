output "iam_role_arns" {
  description = "value of the IAM Role ARNs"
  value = {
    for k, v in var.iam_roles : k => aws_iam_role.roles[k].arn
  }
}
