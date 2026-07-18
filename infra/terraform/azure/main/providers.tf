terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "karmastore"
    container_name       = "staging"
    key                  = "staging.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}