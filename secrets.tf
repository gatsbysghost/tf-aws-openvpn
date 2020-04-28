module "naming" {
  source      = "../../pci/ats-naming"
  environment = var.environment
}

locals {
  secret_prefix = "/${module.naming.prefix}/secrets/actblue/system"
}

resource "aws_ssm_parameter" "foxpass_password" {
  name      = "${local.secret_prefix}/default/foxpass/password"
  type      = "SecureString"
  value     = var.foxpass_password
  overwrite = "true"

  tags = {
    Environment           = var.environment
    "terraform.workspace" = terraform.workspace
    Application           = "OpenVPN Access Server"
  }
}

resource "aws_ssm_parameter" "ovpn_as_password" {
  name      = "${local.secret_prefix}/default/openvpn/admin_password"
  type      = "SecureString"
  value     = var.ovpn_as_password
  overwrite = "true"

  tags = {
    Environment           = var.environment
    "terraform.workspace" = terraform.workspace
    Application           = "OpenVPN Access Server"
  }
}
