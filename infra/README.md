# infra — crisisclothing.com DNS (OpenTofu)

Manages the `crisisclothing.com` Route 53 hosted zone in the dedicated
`crisis-admin` AWS account (`253291597022`). Mirrors the `nw-local-ops/infra`
conventions.

The domain **registration** lives in the `audeos-admin` account
(`037659517213`); this config creates the hosted **zone** in `crisis-admin` and
you repoint the registrar's name servers to it (approach A).

## One-time bootstrap (by hand)

The state bucket is **created by hand, once** — this config never manages its own
state store (a config that manages its own state store is a `tofu destroy` trap
and a circular bootstrap).

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
aws s3api put-public-access-block \
  --bucket crisis-clothing-tfstate \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
  --profile crisis-admin
```

> **Newly created account note:** a brand-new AWS Organizations member account
> can return `NotSignedUp` ("your account is not signed up for the S3 service")
> for a short while after creation. It self-resolves as AWS finishes
> provisioning the account (minutes to a couple hours); retry the bucket
> creation then.

## Apply

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # then edit
tofu init
tofu plan
tofu apply
```

## Delegate the domain (approach A)

After `apply`, take the four name servers:

```bash
tofu output name_servers
```

and set them on the registered domain, which lives in the **audeos-admin**
account:

```bash
aws route53domains update-domain-nameservers \
  --region us-east-1 \
  --domain-name crisisclothing.com \
  --nameservers Name=<ns1> Name=<ns2> Name=<ns3> Name=<ns4> \
  --profile audeos-admin
```

Propagation is usually minutes (can be up to ~48h). Once it resolves, the apex A
records serve the GitHub Pages site and GitHub provisions the TLS certificate for
the custom domain.

## GitHub Pages challenge TXT

When you add the custom domain in the repo's **Settings > Pages**, GitHub shows a
`_github-pages-challenge-…` TXT record. Put its value in `terraform.tfvars`
(`github_pages_challenge_value`) and re-run `tofu apply` to create the record.
(This is only needed for org-level domain *verification*; the apex A + `www`
records are what make the site resolve.)

## Later (tidy-up, optional)

Transfer the domain registration into `crisis-admin` and add an
`aws_route53domains_registered_domain` resource to manage delegation +
`auto_renew` + `transfer_lock` in this config (as `nw-local-ops` does).
