# infra/dns.tf — the crisisclothing.com hosted zone and its records, in the
# dedicated crisis-admin account (253291597022). The domain REGISTRATION lives
# in the audeos-admin account (037659517213); delegation to this zone is
# repointed manually (approach A). See infra/README.md.

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
