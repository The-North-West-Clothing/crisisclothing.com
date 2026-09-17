variable "aws_profile" {
  description = "AWS CLI/SSO profile for the dedicated crisis-admin account that owns the crisisclothing.com hosted zone."
  type        = string
  default     = "crisis-admin"
}

variable "region" {
  description = "AWS region for the provider. Route 53 is global; this is the API region."
  type        = string
  default     = "us-west-2"
}

variable "github_pages_challenge_name" {
  description = <<-EOT
    Name of the GitHub Pages custom-domain challenge TXT record, as GitHub
    displays it when you add the custom domain in repo Settings > Pages. For an
    org-owned repo this is "_github-pages-challenge-the-north-west-clothing".
    Provide the host label only (no domain suffix); the zone name is appended.
  EOT
  type        = string
  default     = "_github-pages-challenge-the-north-west-clothing"
}

variable "github_pages_challenge_value" {
  description = <<-EOT
    Value of the GitHub Pages custom-domain challenge TXT record, supplied by
    GitHub when the custom domain is added. Set in terraform.tfvars (gitignored).
    Leave empty to skip creating the record until you have the value.
  EOT
  type        = string
  default     = ""
}
