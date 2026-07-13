module "halvnais" {
  source = "git::git@github.com:JohanAOstbye/halvnais.git//opentofu?ref=test"

  name = "homelab"

  dns = {
    zone     = "ostbye.dev"
    provider = "cloudflare"
    cloudflare = {
      account_id = "f80f78aaaa6aa38108bb65b2269c5f53"
    }
  }

  secret_management = {
    provider = "openbao"
  }

  auth = {
    provider = "keycloak"
  }

  nodes = {
    provider           = "local"
    kubernetes_version = "1.33.0"
    talos_version      = ""
    pools              = {}
  }

  network_cidr = "10.64.0.0/15"

  hcloud_token                  = var.hcloud_token
  twingate_api_token            = var.twingate_api_token
  cloudflare_api_token          = var.cloudflare_api_token
  tailscale_oauth_client_id     = var.tailscale_oauth_client_id
  tailscale_oauth_client_secret = var.tailscale_oauth_client_secret

  vpn_access = {
    provider = "tailscale"
    tailscale = {
      tags   = ["tag:halvnais"]
      routes = "10.0.0.0/8"
    }
  }
}

module "halvnais-cluster" {
  source = "git::git@github.com:JohanAOstbye/halvnais.git//opentofu/cluster?ref=test"

  cluster_config = module.halvnais.cluster_config
}
