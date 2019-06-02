terraform {
  backend "gcs" {
    bucket = "projectname-terraform-state"
    prefix = "cortex"
  }
}

provider "google" {
  version = "~> 2.5.1"
}

provider "kubernetes" {
  version = "~> 1.7"
}

provider "random" {
  version = "~> 2.1"
}

# Modules
module "cortex_cluster" {
  source = "./cortex-cluster"
}
