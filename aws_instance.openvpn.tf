# CREATE OPENVPN ACCESS SERVER INSTANCE

resource "aws_launch_template" "openvpn" {
  image_id           = var.openvpn_ami
  instance_type      = var.openvpn_instance_size
  key_name           = var.openvpn_key_name

  dynamic "network_interfaces" {
    for_each = var.openvpn_subnet_ids

    content {
      subnet_id = network_interfaces.value
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.openvpn.name
  }

  user_data = data.template_file.user_data.rendered

  vpc_security_group_ids = (var.custom_security_groups == [] ? [aws_security_group.openvpn.id] : coalescelist(var.custom_security_groups, [aws_security_group.openvpn.id]))

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "OpenVPN Access Server"
    Environment = lower(terraform.workspace)
    Stack       = lower(var.stack_name)
  }
}

resource "aws_autoscaling_group" "openvpn" {
  max_size = 1
  min_size = 1

  vpc_zone_identifier = var.openvpn_subnet_ids

  launch_template {
    id = aws_launch_template.openvpn.id
  }
}

# USER DATA TEMPLATE TO PRE-CONFIGURE THE OPENVPN ACCESS SERVER
data "template_file" "user_data" {
  template = file("${path.module}/user_data.tpl")

  vars = {
    public_hostname = var.openvpn_public_hostname
    admin_user      = var.openvpn_admin_user
    admin_pswd      = var.openvpn_admin_pswd
    license_key     = var.openvpn_license
    reroute_gw      = var.openvpn_reroute_gw
    reroute_dns     = var.openvpn_reroute_dns
    ldap_server_1   = var.openvpn_ldap_server_1
    ldap_server_2   = var.openvpn_ldap_server_2
    ldap_bind_dn    = var.openvpn_ldap_bind_dn
    ldap_bind_pswd  = var.openvpn_ldap_bind_pswd
    ldap_base_dn    = var.openvpn_ldap_base_dn
    ldap_uname_attr = var.openvpn_ldap_uname_attr
    ldap_add_req    = var.openvpn_ldap_add_req
    ldap_use_ssl    = var.openvpn_ldap_use_ssl
    use_google_auth = var.use_google_auth
  }
}

locals {
  default_tags = {
    "Name"                = "OpenVPN Access Server"
    "Environment"         = var.stack_name
    "terraform.workspace" = terraform.workspace
  }
}

resource "aws_acm_certificate" "ovpn_aws_cert" {
  domain_name       = var.cert_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_lb" "lb" {
  name                   = var.stack_name
  load_balancer_type     = "network"
  subnets                = var.openvpn_subnet_ids
  tags                   = local.default_tags
}

resource "aws_lb_listener" "lb_https" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-2018-06"

  certificate_arn   = aws_acm_certificate.ovpn_aws_cert.arn // WIP

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_lb_listener" "lb_http" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "openvpn" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "1194"
  protocol          = "UDP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.openvpn-1194.arn
  }
}

resource "aws_lb_listener" "openvpn-943" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "943"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.openvpn-943.arn
  }
}

resource "aws_route53_record" "lb" {
  zone_id = var.openvpn_route53_public_zone_id
  name    = var.openvpn_public_dns
  type    = "CNAME"
  ttl     = "30"
  records = [aws_lb.lb.dns_name]
}

resource "aws_lb_target_group" "tg" {
  name     = "${var.stack_name}-tg"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = var.network_vpc_id
  tags     = local.default_tags

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = "2"
    unhealthy_threshold = "3"
    timeout             = "5"
    interval            = "10"
    matcher             = "200,204"
  }
}

resource "aws_lb_target_group" "openvpn-1194" {
  name     = "${var.stack_name}-ovpn-tg-1194"
  port     = "1194"
  protocol = "UDP"
  vpc_id   = var.network_vpc_id
  tags     = local.default_tags
}

resource "aws_lb_target_group" "openvpn-943" {
  name     = "${var.stack_name}-ovpn-tg-943"
  port     = "943"
  protocol = "TCP"
  vpc_id   = var.network_vpc_id
  tags     = local.default_tags
}

