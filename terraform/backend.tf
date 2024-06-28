terraform {
  backend "s3" {
    bucket = "my-backend-tf-scw-tidb-k8s"
    key    = "terraform.tfstate"
    region = "fr-par"
    endpoints = {
      s3 = "https://s3.fr-par.scw.cloud"
    }
    skip_requesting_account_id  = true
    skip_credentials_validation = true
    skip_region_validation      = true
  }
}
