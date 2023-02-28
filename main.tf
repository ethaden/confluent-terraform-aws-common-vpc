module "terraform_pki" {
    source = "github.com/ethaden/terraform-local-pki.git"

    cert_path = "./generated/client_vpn_pki"
    organization = "Confluent Inc"
    ca_common_name = "Confluent Inc ${local.username} Test CA"
    server_names = ["vpn-gateway"]
    client_names = ["${local.username}-laptop"]
}

# Import existing: terraform import aws_vpc.vpc_dualstack <AWS Resource ID>
resource "aws_vpc" "vpc_dualstack" {
  assign_generated_ipv6_cidr_block = true
  cidr_block = "172.29.0.0/24"
  enable_dns_hostnames = true

   tags = {
     Name = "${local.resource_prefix}-common"
   }

  lifecycle {
    prevent_destroy = true
  }
}

# Import existing: terraform import aws_subnet.subnet_dualstack <AWS Resource ID>
resource "aws_subnet" "subnet_dualstack" {
  vpc_id     = aws_vpc.vpc_dualstack.id
  cidr_block = aws_vpc.vpc_dualstack.cidr_block
  ipv6_cidr_block   = "${cidrsubnet(aws_vpc.vpc_dualstack.ipv6_cidr_block, 8, 0)}"
  availability_zone = "eu-central-1a"
  assign_ipv6_address_on_creation = true
  enable_resource_name_dns_a_record_on_launch = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.resource_prefix}-common"
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

# Import existing: terraform import aws_route_table.rtb_dualstack <AWS Resource ID>
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
    prevent_destroy = true
  }
}

# Import existing: terraform import aws_default_network_acl.acl_default <AWS Resource ID>
resource "aws_default_network_acl" "acl_default" {
  default_network_acl_id = aws_vpc.vpc_dualstack.default_network_acl_id
  subnet_ids = [ aws_subnet.subnet_dualstack.id ]
  
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

  ingress {
    protocol = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
    icmp_code  = 0
    icmp_type  = 0
  }

  ingress {
    protocol = "-1"
    rule_no = 101
    action     = "allow"
    ipv6_cidr_block = "::/0"
    from_port  = 0
    to_port    = 0
    icmp_code  = 0
    icmp_type  = 0
  }


  tags = {
    Name = "${local.resource_prefix}-common"
  }
}

output "pki_ca_key" {
    sensitive = true
    value = module.terraform_pki.ca_cert.private_key_pem
}

output "pki_ca_cert" {
    sensitive = true
    value = module.terraform_pki.ca_cert.cert_pem
}

output "pki_vpn_gw_key" {
    sensitive = true
    value = module.terraform_pki.server_keys["vpn-gateway"].private_key_pem
}

output "pki_vpn_gw_cert" {
    sensitive = true
    value = module.terraform_pki.server_certs["vpn-gateway"].cert_pem
}

output "pki_laptop_key" {
    sensitive = true
    value = module.terraform_pki.client_keys["${local.username}-laptop"].private_key_pem
}

output "pki_laptop_cert" {
    value = module.terraform_pki.client_certs["${local.username}-laptop"].cert_pem
}
