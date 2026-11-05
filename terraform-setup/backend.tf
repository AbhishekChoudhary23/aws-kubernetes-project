terraform {

  backend "s3" {

    bucket = "terraform-sandbox-988067790077-ap-south-1-an"

    key = "state-file/terraform-sandbox.tfstate"

    region = "ap-south-1"

    encrypt = true

  }

}