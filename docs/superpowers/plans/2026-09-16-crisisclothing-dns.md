# Crisis Clothing DNS-as-Code — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Manage the `crisisclothing.com` Route 53 hosted zone as code (OpenTofu) so the apex + `www` point at the GitHub Pages site, mirroring the `nw-local-ops/infra` pattern.

**Architecture:** A self-contained `infra/` OpenTofu config in this repo, targeting a new dedicated `crisis-admin` AWS account. State in S3 with native lockfile. The config **creates** the hosted zone and its records; the registrar's name-server delegation is repointed manually (approach A — the domain registration currently lives in a different, existing account).

**Tech Stack:** OpenTofu `>= 1.10`, `hashicorp/aws ~> 6.0`, AWS Route 53, S3 remote state.

**Spec:** `docs/superpowers/specs/2026-09-16-crisisclothing-gallery-design.md`

## Global Constraints

- OpenTofu `required_version >= 1.10`; `hashicorp/aws ~> 6.0`.
- **Backend blocks cannot reference variables** — every backend value is a literal.
- S3 backend: bucket `crisis-clothing-tfstate`, key `infra/terraform.tfstate`, region `us-west-2`, profile `crisis-admin`, `encrypt = true`, `use_lockfile = true`.
- The state bucket is **created by hand, once** — the config never manages its own state store (a config that manages its own state store is a `tofu destroy` trap and a circular bootstrap; same rationale as `nw-local-ops`).
- Provider `profile = var.aws_profile` (default `crisis-admin`); `default_tags` = `{ Project = "crisisclothing.com", Environment = "production", ManagedBy = "opentofu", Repo = "The-North-West-Clothing/crisisclothing.com" }`.
- GitHub Pages apex IPs: `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`.
- `www` CNAME → `the-north-west-clothing.github.io`.
- No secrets committed. `infra/*.tfvars` is gitignored; `terraform.tfvars.example` is tracked.
- Local verification gate (no account needed): `tofu fmt -check` and `tofu init -backend=false && tofu validate`. `tofu plan`/`apply` are manual operator steps requiring the account + state bucket.

---

### Task 1: Provider, backend, and variables

**Files:**
- Create: `infra/main.tf`
- Create: `infra/variables.tf`
- Create: `infra/terraform.tfvars.example`

**Interfaces:**
- Consumes: nothing.
- Produces: `var.aws_profile`, `var.region`, `var.github_pages_challenge_value`, `var.github_pages_challenge_name`; a configured `aws` provider and S3 backend.

- [ ] **Step 1: Create `infra/main.tf`**

```hcl
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State lives in an S3 bucket this configuration deliberately does NOT manage
  # (see infra/README.md for the one-time bootstrap). A config that manages its
  # own state store is a `tofu destroy` trap and a circular bootstrap.
  #
  # Backend blocks are read before the rest of the configuration is evaluated,
  # so every value MUST be a literal — `profile = var.aws_profile` is a parse
  # error. `profile` is required: the backend does not inherit the provider's
  # credentials, and omitting it fails `tofu init` with a confusing
  # "No valid credential sources found" after a 30s metadata-endpoint timeout.
  backend "s3" {
    bucket       = "crisis-clothing-tfstate"
    key          = "infra/terraform.tfstate"
    region       = "us-west-2"
    profile      = "crisis-admin"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "crisisclothing.com"
      Environment = "production"
      ManagedBy   = "opentofu"
      Repo        = "The-North-West-Clothing/crisisclothing.com"
    }
  }
}
```

- [ ] **Step 2: Create `infra/variables.tf`**

```hcl
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
```

- [ ] **Step 3: Create `infra/terraform.tfvars.example`**

```hcl
# Copy to terraform.tfvars (gitignored) and fill in.
# aws_profile = "crisis-admin"
# region      = "us-west-2"

# From GitHub repo Settings > Pages, after adding the custom domain:
# github_pages_challenge_name  = "_github-pages-challenge-the-north-west-clothing"
# github_pages_challenge_value = "<value GitHub shows you>"
```

- [ ] **Step 4: Format and validate (offline)**

Run:
```bash
cd infra && tofu fmt -check && tofu init -backend=false && tofu validate
```
Expected: `fmt` reports no changes; `validate` reports "Success! The configuration is valid."

- [ ] **Step 5: Commit**

```bash
git add infra/main.tf infra/variables.tf infra/terraform.tfvars.example
git commit -m "Add OpenTofu provider, S3 backend, and variables for crisisclothing.com DNS"
```

---

### Task 2: Hosted zone and DNS records

**Files:**
- Create: `infra/dns.tf`
- Create: `infra/outputs.tf`

**Interfaces:**
- Consumes: the provider from Task 1 and its variables.
- Produces: `aws_route53_zone.primary`; apex A, `www` CNAME, and conditional challenge TXT records; `output "name_servers"` for the manual registrar repoint.

- [ ] **Step 1: Create `infra/dns.tf`**

```hcl
# infra/dns.tf — the crisisclothing.com hosted zone and its records, in the
# dedicated crisis-admin account. The domain REGISTRATION currently lives in a
# different existing account (to confirm at apply time); delegation to this zone
# is repointed manually (approach A). See the spec, DNS section.

resource "aws_route53_zone" "primary" {
  name    = "crisisclothing.com"
  comment = "Primary zone for crisisclothing.com; GitHub Pages design gallery."
}

# --- Apex: gallery site on GitHub Pages ---
resource "aws_route53_record" "apex_a" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "crisisclothing.com"
  type    = "A"
  ttl     = 3600
  records = [
    "185.199.108.153",
    "185.199.109.153",
    "185.199.110.153",
    "185.199.111.153",
  ]
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.crisisclothing.com"
  type    = "CNAME"
  ttl     = 3600
  records = ["the-north-west-clothing.github.io"]
}

# --- GitHub Pages custom-domain challenge TXT. Created only once the value is
#     provided (from repo Settings > Pages). count keeps `tofu apply` usable
#     before the value is known. ---
resource "aws_route53_record" "github_pages_challenge" {
  count   = var.github_pages_challenge_value == "" ? 0 : 1
  zone_id = aws_route53_zone.primary.zone_id
  name    = "${var.github_pages_challenge_name}.crisisclothing.com"
  type    = "TXT"
  ttl     = 300
  records = [var.github_pages_challenge_value]
}
```

- [ ] **Step 2: Create `infra/outputs.tf`**

```hcl
output "name_servers" {
  description = "Set these as the domain's name servers at the registrar (in the account holding the registration) to delegate crisisclothing.com to this zone."
  value       = aws_route53_zone.primary.name_servers
}

output "zone_id" {
  description = "Route 53 hosted zone ID for crisisclothing.com."
  value       = aws_route53_zone.primary.zone_id
}
```

- [ ] **Step 3: Format and validate (offline)**

Run:
```bash
cd infra && tofu fmt -check && tofu init -backend=false && tofu validate
```
Expected: `fmt` clean; `validate` succeeds.

- [ ] **Step 4: Commit**

```bash
git add infra/dns.tf infra/outputs.tf
git commit -m "Add crisisclothing.com hosted zone, records, and outputs"
```

---

### Task 3: Operator runbook (infra/README.md)

**Files:**
- Create: `infra/README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the manual bootstrap + apply + delegation runbook.

- [ ] **Step 1: Create `infra/README.md`**

```markdown
# infra — crisisclothing.com DNS (OpenTofu)

Manages the `crisisclothing.com` Route 53 hosted zone in the dedicated
`crisis-admin` AWS account. Mirrors the `nw-local-ops/infra` conventions.

## One-time bootstrap (by hand)

1. **Create the `crisis-admin` AWS account** as a member of the AWS Organization
   (Organizations > Add an AWS account), then create a local SSO profile named
   `crisis-admin`:

   ```bash
   aws configure sso   # profile name: crisis-admin, region: us-west-2
   aws sso login --profile crisis-admin
   ```

2. **Create the state bucket** (this config does not manage it):

   ```bash
   aws s3api create-bucket \
     --bucket crisis-clothing-tfstate \
     --region us-west-2 \
     --create-bucket-configuration LocationConstraint=us-west-2 \
     --profile crisis-admin
   aws s3api put-bucket-versioning \
     --bucket crisis-clothing-tfstate \
     --versioning-configuration Status=Enabled \
     --profile crisis-admin
   aws s3api put-bucket-encryption \
     --bucket crisis-clothing-tfstate \
     --server-side-encryption-configuration \
     '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
     --profile crisis-admin
   ```

## Apply

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # then edit
tofu init
tofu plan
tofu apply
```

## Delegate the domain (approach A)

The domain **registration** currently lives in a different account (confirm
which — likely `audeos-admin`). After `apply`, take the four name servers from:

```bash
tofu output name_servers
```

and set them as the domain's name servers in the **registration** account
(Route 53 > Registered domains > crisisclothing.com > Add/edit name servers, or
Domains > update-domain-nameservers). Propagation takes up to ~48h but usually
minutes.

## GitHub Pages challenge TXT

When you add the custom domain in the repo's **Settings > Pages**, GitHub shows a
`_github-pages-challenge-…` TXT record. Put its value in `terraform.tfvars`
(`github_pages_challenge_value`) and re-run `tofu apply` to create the record.

## Later (tidy-up, optional)

Transfer the domain registration into `crisis-admin` and add an
`aws_route53domains_registered_domain` resource to manage delegation +
`auto_renew` + `transfer_lock` in this config (as `nw-local-ops` does).
```

- [ ] **Step 2: Commit**

```bash
git add infra/README.md
git commit -m "Add DNS operator runbook"
```

---

## Self-review notes

- **Spec coverage:** new `crisis-admin` account + S3 backend pattern (Task 1), zone + apex A + www CNAME + challenge TXT (Task 2), approach-A manual delegation + manual bootstrap (Task 3 README). The registrar-account and challenge-TXT "confirm at apply time" open items are surfaced in the README, not hardcoded.
- **No placeholders / type consistency:** variable names (`github_pages_challenge_name/value`) are used consistently between `variables.tf` and `dns.tf`; the `count` guard lets `apply` run before the challenge value is known.
- **Deferred (out of scope, per spec):** domain-registration transfer and `aws_route53domains_registered_domain` — noted as later tidy-up.
```
