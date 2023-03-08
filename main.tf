module "terraform_pki" {
    source = "github.com/ethaden/terraform-local-pki.git"

    cert_path = "${var.generated_files_path}/client_vpn_pki"
    organization = "Confluent Inc"
    ca_common_name = "Confluent Inc ${local.username} Test CA"
    server_names = { "vpn-gateway": "vpn-gateway.${var.vpn_base_domain}" }
    client_names = local.vpn_client_names_to_domain
    # Unfortunately, AWS Client VPN Endpoints only support RSA with max. 2048 bits
    algorithm = "RSA"
    rsa_bits = 2048
}

# Import existing: terraform import aws_vpc.vpc_dualstack <AWS Resource ID>
resource "aws_vpc" "vpc_dualstack" {
  assign_generated_ipv6_cidr_block = true
  cidr_block = "172.29.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

   tags = {
     Name = "${local.resource_prefix}-common"
   }

  lifecycle {
    prevent_destroy = false
  }
}


resource "aws_default_security_group" "sg_default" {
  vpc_id = aws_vpc.vpc_dualstack.id

  ingress {
    description = ""
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  ingress {
    description = ""
    protocol  = -1
    from_port = 0
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description = ""
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Import existing: terraform import aws_subnet.subnet_dualstack_1a <AWS Resource ID>
resource "aws_subnet" "subnet_dualstack_1a" {
  vpc_id     = aws_vpc.vpc_dualstack.id
  cidr_block = "${cidrsubnet(aws_vpc.vpc_dualstack.cidr_block, 8, 0)}"
  ipv6_cidr_block   = "${cidrsubnet(aws_vpc.vpc_dualstack.ipv6_cidr_block, 8, 0)}"
  availability_zone = "eu-central-1a"
  assign_ipv6_address_on_creation = true
  enable_resource_name_dns_a_record_on_launch = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.resource_prefix}-common-1-1a"
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_subnet" "subnet_dualstack_1b" {
  vpc_id     = aws_vpc.vpc_dualstack.id
  cidr_block = "${cidrsubnet(aws_vpc.vpc_dualstack.cidr_block, 8, 1)}"
  ipv6_cidr_block   = "${cidrsubnet(aws_vpc.vpc_dualstack.ipv6_cidr_block, 8, 1)}"
  availability_zone = "eu-central-1b"
  assign_ipv6_address_on_creation = true
  enable_resource_name_dns_a_record_on_launch = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.resource_prefix}-common-2-1b"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_subnet" "subnet_dualstack_1c" {
  vpc_id     = aws_vpc.vpc_dualstack.id
  cidr_block = "${cidrsubnet(aws_vpc.vpc_dualstack.cidr_block, 8, 2)}"
  ipv6_cidr_block   = "${cidrsubnet(aws_vpc.vpc_dualstack.ipv6_cidr_block, 8, 2)}"
  availability_zone = "eu-central-1c"
  assign_ipv6_address_on_creation = true
  enable_resource_name_dns_a_record_on_launch = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.resource_prefix}-common-3-1c"
  }
  lifecycle {
    prevent_destroy = true
  }
}

# Import existing: terraform import aws_internet_gateway.igw_dualstack <AWS Resource ID>
resource "aws_internet_gateway" "igw_dualstack" {
  vpc_id = aws_vpc.vpc_dualstack.id

  tags = {
    Name = "${local.resource_prefix}-common"
  }
  lifecycle {
    prevent_destroy = true
  }
}

# Following best-practices, I create a second route table used for internet connectivity
resource "aws_route_table" "rtb_dualstack" {
  vpc_id = aws_vpc.vpc_dualstack.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_dualstack.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.igw_dualstack.id
  }

  tags = {
    Name = "${local.resource_prefix}-common"
  }
  lifecycle {
    prevent_destroy = false
  }
}

# Import existing: terraform import aws_default_network_acl.acl_default <AWS Resource ID>
resource "aws_default_network_acl" "acl_default" {
  default_network_acl_id = aws_vpc.vpc_dualstack.default_network_acl_id
  subnet_ids = [ aws_subnet.subnet_dualstack_1a.id, aws_subnet.subnet_dualstack_1b.id, aws_subnet.subnet_dualstack_1c.id ]
  egress {
    protocol = "-1"
    rule_no = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
    icmp_code  = 0
    icmp_type  = 0
  }

  egress {
    protocol = "-1"
    rule_no = 101
    action     = "allow"
    ipv6_cidr_block = "::/0"
    from_port  = 0
    to_port    = 0
    icmp_code  = 0
    icmp_type  = 0
  }

  # Generate IPv4 ingress for for the following tcp ports: 22 (ssh), 80 (http), 443 (https)
  dynamic "ingress" {
    for_each = {1: 22, 2: 80, 3: 443}
    content {
      protocol = "tcp"
      rule_no    = ingress.key
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = ingress.value
      to_port    = ingress.value
      icmp_code  = 0
      icmp_type  = 0
    }
  }

  # Generate IPv6 ingress for for the following tcp ports: 22 (ssh), 80 (http), 443 (https)
  dynamic "ingress" {
    for_each = {20: 22, 21: 80, 22: 443}
    content {
      protocol = "tcp"
      rule_no    = ingress.key
      action     = "allow"
      ipv6_cidr_block = "::/0"
      from_port  = ingress.value
      to_port    = ingress.value
      icmp_code  = 0
      icmp_type  = 0
    }
  }
  # Allow ingress vom VPN
  ingress {
    protocol = "-1"
    rule_no    = 97
    action     = "allow"
    cidr_block = aws_ec2_client_vpn_endpoint.vpn.client_cidr_block
    from_port  = 0
    to_port    = 0
    icmp_code  = 0
    icmp_type  = 0
  }

  # Allow everything within the VPC
  ingress {
    protocol = "-1"
    rule_no    = 98
    action     = "allow"
    cidr_block = aws_vpc.vpc_dualstack.cidr_block
    from_port  = 0
    to_port    = 0
    icmp_code  = 0
    icmp_type  = 0
  }

  ingress {
    protocol = "-1"
    rule_no    = 99
    action     = "allow"
    ipv6_cidr_block = aws_vpc.vpc_dualstack.ipv6_cidr_block
    from_port  = 0
    to_port    = 0
    icmp_code  = 0
    icmp_type  = 0
  }  # ingress {
  #   protocol = "-1"
  #   rule_no    = 100
  #   action     = "allow"
  #   cidr_block = "0.0.0.0/0"
  #   from_port  = 0
  #   to_port    = 0
  #   icmp_code  = 0
  #   icmp_type  = 0
  # }

  # ingress {
  #   protocol = "-1"
  #   rule_no    = 101
  #   action     = "allow"
  #   ipv6_cidr_block = "::/0"
  #   from_port  = 0
  #   to_port    = 0
  #   icmp_code  = 0
  #   icmp_type  = 0
  # }

  tags = {
    Name = "${local.resource_prefix}-common"
  }
}

# For enabling internet access, I assign each subnet to the second router table
resource "aws_route_table_association" "subet_assoc_1" {
 subnet_id      = aws_subnet.subnet_dualstack_1a.id
 route_table_id = aws_route_table.rtb_dualstack.id
}
resource "aws_route_table_association" "subet_assoc_2" {
 subnet_id      = aws_subnet.subnet_dualstack_1b.id
 route_table_id = aws_route_table.rtb_dualstack.id
}
resource "aws_route_table_association" "subet_assoc_3" {
 subnet_id      = aws_subnet.subnet_dualstack_1c.id
 route_table_id = aws_route_table.rtb_dualstack.id
}

resource "aws_route53_zone" "private_hostedzone_vpc" {
  name = local.private_hostedzone_vpc

  vpc {
    vpc_id = aws_vpc.vpc_dualstack.id
  }
}

# Upload all our custom certificates including the CA certificate to AWS
resource "aws_acm_certificate" "ca_cert" {
  private_key      = module.terraform_pki.ca_cert.private_key_pem
  certificate_body = module.terraform_pki.ca_cert.cert_pem
}

resource "aws_acm_certificate" "vpn_gw_cert" {
  private_key      = module.terraform_pki.server_keys["vpn-gateway"].private_key_pem
  certificate_body = module.terraform_pki.server_certs["vpn-gateway"].cert_pem
}

resource "aws_security_group" "sg_client_vpn" {
  vpc_id     = aws_vpc.vpc_dualstack.id

  egress {
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
    from_port  = 0
    to_port    = 0
  }
  ingress {
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
    from_port  = 0
    to_port    = 0
  }
  tags = {
    Name = "${local.resource_prefix}-common"
  }
}

resource "aws_ec2_client_vpn_endpoint" "vpn" {
  description = "Client VPN for secure access"
  vpc_id     = aws_vpc.vpc_dualstack.id
  security_group_ids = [ aws_security_group.sg_client_vpn.id ]
  client_cidr_block = "10.23.0.0/22"
  split_tunnel = true
  server_certificate_arn = aws_acm_certificate.vpn_gw_cert.arn

   dns_servers = [
     aws_route53_resolver_endpoint.vpn_dns.ip_address.*.ip[0], 
     aws_route53_resolver_endpoint.vpn_dns.ip_address.*.ip[1],
     aws_route53_resolver_endpoint.vpn_dns.ip_address.*.ip[2]
   ]
  authentication_options {
    type = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.ca_cert.arn
  }

  connection_log_options {
    enabled = false
  }

  tags = {
    Name = "${local.resource_prefix}-common"
  }
}

# VPN clients are authorized to access everything accessible via the VPN
resource "aws_ec2_client_vpn_authorization_rule" "vpn_auth_rule" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  target_network_cidr    = aws_subnet.subnet_dualstack_1a.cidr_block
  authorize_all_groups   = true
}

resource "aws_ec2_client_vpn_authorization_rule" "vpn_auth_rule_2" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  target_network_cidr    = aws_subnet.subnet_dualstack_1b.cidr_block
  authorize_all_groups   = true
}

resource "aws_ec2_client_vpn_authorization_rule" "vpn_auth_rule_3" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  target_network_cidr    = aws_subnet.subnet_dualstack_1c.cidr_block
  authorize_all_groups   = true
}

# Associate the vpn with the subnet in the vpc. This will also create a route
resource "aws_ec2_client_vpn_network_association" "vpn_network_association_1" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  subnet_id              = aws_subnet.subnet_dualstack_1a.id
}

resource "aws_ec2_client_vpn_network_association" "vpn_network_association_2" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  subnet_id              = aws_subnet.subnet_dualstack_1b.id
}

resource "aws_ec2_client_vpn_network_association" "vpn_network_association_3" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  subnet_id              = aws_subnet.subnet_dualstack_1c.id
}

resource aws_route53_resolver_endpoint "vpn_dns" {
   name = "vpn-dns-access"
   direction = "INBOUND"
   security_group_ids = [aws_security_group.vpn_dns_sg.id]

   ip_address {
     subnet_id = aws_subnet.subnet_dualstack_1a.id
   }
   ip_address {
     subnet_id = aws_subnet.subnet_dualstack_1b.id
   }

   ip_address {
     subnet_id = aws_subnet.subnet_dualstack_1c.id
   }
  tags = {
    Name = "${local.resource_prefix}-common"
  }
 }

resource aws_security_group "vpn_dns_sg" {
   name = "${local.resource_prefix}-common"
   vpc_id = aws_vpc.vpc_dualstack.id
   ingress {
     from_port = 0
     protocol = "-1"
     to_port = 0
     security_groups = [aws_security_group.sg_client_vpn.id]
   }
   egress {
     from_port = 0
     protocol = "-1"
     to_port = 0
     cidr_blocks = ["0.0.0.0/0"]
     ipv6_cidr_blocks = ["::/0"]
   }
 }

# data "template_file" "aws_openvpn_configs" {
#   for_each = client_names
#   template = "${file("${path.module}/templates/aws-openvpn-config.tpl")}"
#   vars = {
#     ca_cert_pem = "${module.terraform_pki.ca_cert.cert_pem}"
#     client_cert_pem = module.terraform_pki.client_certs[each.key].cert_pem
#     client_key_pem = module.terraform_pki.client_keys[each.key].private_key_pem
#   }
# }

resource "local_sensitive_file" "aws_openvpn_config_files" {
  for_each = toset(local.vpn_client_names)

  #content  = template_file.aws_openvpn_configs[each.key].rendered
  content = templatefile("${path.module}/templates/aws-openvpn-config.tpl",
  {
    vpn_gateway_endpoint = aws_ec2_client_vpn_endpoint.vpn.dns_name,
    ca_cert_pem = "${module.terraform_pki.ca_cert.cert_pem}",
    client_cert_pem = module.terraform_pki.client_certs[each.key].cert_pem,
    client_key_pem = module.terraform_pki.client_keys[each.key].private_key_pem
  }
  )
  filename = "${var.generated_files_path}/openvpn_config_files/openvpn-config-${each.key}.ovpn"
}


output "vpn-gateway-dns-name" {
    value = aws_ec2_client_vpn_endpoint.vpn.dns_name
}

# output "pki_ca_cert" {
#     sensitive = true
#     value = module.terraform_pki.ca_cert.cert_pem
# }

# output "pki_vpn_gw_key" {
#     sensitive = true
#     value = module.terraform_pki.server_keys["vpn-gateway"].private_key_pem
# }

# output "pki_vpn_gw_cert" {
#     sensitive = true
#     value = module.terraform_pki.server_certs["vpn-gateway"].cert_pem
# }

# output "pki_laptop_key" {
#     sensitive = true
#     value = module.terraform_pki.client_keys["${local.username}-laptop"].private_key_pem
# }

resource "aws_key_pair" "ssh_key_default" {
  key_name   = "${local.resource_prefix}-common"
  public_key = local.public_ssh_key
}


# There outputs make the resources available via remote state data source
output vpc_dualstack {
  value = aws_vpc.vpc_dualstack
}

output subnet_dualstack_1a {
  value = aws_subnet.subnet_dualstack_1a
}

output subnet_dualstack_1b {
  value = aws_subnet.subnet_dualstack_1b
}

output subnet_dualstack_1c {
  value = aws_subnet.subnet_dualstack_1c
}

output "ssh_key_default" {
  value = aws_key_pair.ssh_key_default
}

output "private_hostedzone_vpc" {
  value = aws_route53_zone.private_hostedzone_vpc
}
