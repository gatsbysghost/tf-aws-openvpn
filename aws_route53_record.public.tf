# ROUTE53 PUBLIC DNS
resource "aws_route53_record" "public" {
  zone_id = var.openvpn_route53_public_zone_id
  name    = var.openvpn_public_dns
  type    = "CNAME"
  ttl     = "300"
  records = [aws_lb.lb.dns_name]
}
