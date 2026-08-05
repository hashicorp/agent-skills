terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "vault_kv_secret_v2" "tls" {
  mount = var.mount
  name  = var.secret_name

  data_json = jsonencode({
    private_key = tls_private_key.this.private_key_pem
  })
}
