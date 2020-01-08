# ROUTE53 PUBLIC DNS
// TODO
resource "aws_route53_record" "public" {
  zone_id = var.openvpn_route53_public_zone_id
  name    = var.openvpn_public_dns
  type    = "A"
  ttl     = "300"
  # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
  # force an interpolation expression to be interpreted as a list by wrapping it
  # in an extra set of list brackets. That form was supported for compatibility in
  # v0.11, but is no longer supported in Terraform v0.12.
  #
  # If the expression in the following list itself returns a list, remove the
  # brackets to avoid interpretation as a list of lists. If the expression
  # returns a single list item then leave it as-is and remove this TODO comment.
  records = [local.public_ip]
}

