output "name_servers" {
  description = "Set these as the domain's name servers at the registrar (audeos-admin account) to delegate crisisclothing.com to this zone."
  value       = aws_route53_zone.primary.name_servers
}

output "zone_id" {
  description = "Route 53 hosted zone ID for crisisclothing.com."
  value       = aws_route53_zone.primary.zone_id
}
