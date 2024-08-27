terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "ctx" {}

locals {
  hcp_terraform_url = "https://${var.hcp_terraform_fqdn}"
}

data "tls_certificate" "tfc" {
  url = local.hcp_terraform_url
}

resource "aws_iam_openid_connect_provider" "oidc" {
  url             = local.hcp_terraform_url
  client_id_list  = var.client_id_list
  thumbprint_list = [data.tls_certificate.tfc.certificates.0.sha1_fingerprint]
}

data "aws_iam_policy_document" "trust" {
  for_each = var.iam_roles

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.hcp_terraform_fqdn}:aud"
      values   = var.client_id_list
    }

    condition {
      test     = "StringLike"
      variable = "${var.hcp_terraform_fqdn}:sub"
      values   = [each.value.subject_name]
    }
  }
}

data "aws_iam_policy_document" "permissions" {
  for_each = var.iam_roles

  statement {
    actions = each.value.permissions
    effect  = "Allow"

    resources = ["*"]
  }
}

resource "aws_iam_role" "roles" {
  for_each = var.iam_roles

  name               = each.key
  description        = join(" ", [each.value.description, each.value.subject_name])
  assume_role_policy = data.aws_iam_policy_document.trust[each.key].json

  inline_policy {
    name   = join("-", [each.key, "permissions"])
    policy = data.aws_iam_policy_document.permissions[each.key].json
  }
}

data "aws_iam_policy_document" "member_trust" {
  for_each = var.iam_roles

  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.ctx.account_id}:root"]
    }
  }
}

data "aws_iam_policy_document" "member_permissions" {
  for_each = var.iam_roles

  statement {
    actions = each.value.permissions
    effect  = "Allow"

    resources = ["*"]
  }
}

resource "aws_iam_role" "member_roles" {
  for_each = var.iam_roles

  name               = "${each.key}-member"
  description        = join(" ", [each.value.description, each.value.subject_name])
  assume_role_policy = data.aws_iam_policy_document.member_trust[each.key].json

  inline_policy {
    name   = join("-", [each.key, "permissions"])
    policy = data.aws_iam_policy_document.member_permissions[each.key].json
  }
}
