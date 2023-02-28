terraform {
  required_providers {
    confluent = {
      source = "confluentinc/confluent"
      version = "1.25.0"
    }
  }
}
provider "aws" {
    region = var.aws_region

    default_tags {
      tags = local.confluent_tags
    }
}

# resource "random_id" "id" {
#   byte_length = 4
# }
