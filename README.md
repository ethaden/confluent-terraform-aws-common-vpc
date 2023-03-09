# Share VPC using Terraform Remote State in S3
This terraform configuration sets up a Terraform S3 remote state for shared resources.

CAUTION: Everything contained in this repository is not supported by Confluent.

Note, that additional measures (e.g. locking) might be required if this state store is accessed concurrently by multiple users.

You can find a configuration to set up the Terraform S3 remote state bucket here: https://github.com/ethaden/confluent-terraform-aws-tfstate-s3.

## Precondition
Obviously, you need to have an AWS account with proper credentials set up.

## Usage
First you might want to customize `variables.tf` or create a local file `terraform.tfvars` where you set values for certain variables.
This configuration re-uses a common network setup available via a Terraform S3 remote state. This needs to be set up first.

Then you just run terraform and look at the plan (optional step):

```bash
terraform plan
```

Execute the plan by running:

```bash
terraform apply
```

You can delete the generated resources by running:

```bash
terraform destroy
```

However, as deleting a used terraform remote state might have devestating consequences, I blocked deletion by default by setting the lifecycle variable `prevent_destroy=true`. If you really want to delete the storage using terraform, set these variables to `false` first.

## DISCLAIMER
THIS CONFIGURATION IS MEANT FOR TESTING ONLY AND NOT FOR PRODUCTION. PLEASE CHECK THE [LICENSE](LICENSE) FOR FURTHER INFORMATION.

