resource "random_integer" "subnet_idx" {
  min = 0
  max = (length(var.openvpn_subnet_ids) - 1)
}

# CREATE OPENVPN ACCESS SERVER INSTANCE

resource "aws_launch_configuration" "openvpn" {
  image_id           = var.openvpn_ami
  instance_type      = var.openvpn_instance_size
  key_name           = var.openvpn_key_name

  iam_instance_profile = aws_iam_instance_profile.openvpn.name

  user_data = data.template_file.user_data.rendered

  security_groups = (var.custom_security_groups == [] ? [aws_security_group.openvpn.id] : coalescelist(var.custom_security_groups, [aws_security_group.openvpn.id]))

  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "openvpn" {
  max_size             = 1
  min_size             = 1
  vpc_zone_identifier  = [var.openvpn_subnet_ids[random_integer.subnet_idx.result]]
  launch_configuration = aws_launch_configuration.openvpn.name
  health_check_type    = "EC2"
  target_group_arns    = [aws_lb_target_group.tg-443.arn, aws_lb_target_group.tg-943.arn, aws_lb_target_group.tg-1194.arn]

  tags = [{
    key   = "Name",
    value = "OpenVPN Access Server",
    propagate_at_launch = true
  },
  {
    key   = "Environment",
    value = lower(terraform.workspace),
    propagate_at_launch = true
  },
  {
    key   = "Stack",
    value = lower(var.stack_name),
    propagate_at_launch = true
  }]
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
    private_subnet  = var.private_subnet
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
  subnets                = [var.openvpn_subnet_ids[random_integer.subnet_idx.result]]
  tags                   = local.default_tags
}

resource "aws_lb_listener" "openvpn-443" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "443"
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-FS-2018-06"

  certificate_arn   = aws_acm_certificate.ovpn_aws_cert.arn // WIP

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-443.arn
  }
}

resource "aws_lb_listener" "openvpn-1194" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "1194"
  protocol          = "UDP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-1194.arn
  }
}

resource "aws_lb_listener" "openvpn-943" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "943"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-943.arn
  }
}

resource "aws_lb_target_group" "tg-443" {
  name     = "${var.stack_name}-tg-443"
  port     = "443"
  protocol = "TLS"
  vpc_id   = var.network_vpc_id
  tags     = local.default_tags

  health_check {
    path                = "/"
    protocol            = "HTTPS"
    healthy_threshold   = "3"
    unhealthy_threshold = "3"
    interval            = "10"
  }
}

resource "aws_lb_target_group" "tg-1194" {
  name     = "${var.stack_name}-tg-1194"
  port     = "1194"
  protocol = "UDP"
  vpc_id   = var.network_vpc_id
  tags     = local.default_tags
}

resource "aws_lb_target_group" "tg-943" {
  name     = "${var.stack_name}-tg-943"
  port     = "943"
  protocol = "TCP"
  vpc_id   = var.network_vpc_id
  tags     = local.default_tags
}


