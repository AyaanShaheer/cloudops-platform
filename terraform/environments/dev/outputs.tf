output "github_actions_role_arn" {
  value = module.iam_oidc.role_arn
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}