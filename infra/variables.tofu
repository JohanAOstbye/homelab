variable "hcloud_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "twingate_api_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token used by the halvnais module to provision a scoped zone token and Cloudflare Tunnel. Needs Zone:Read + DNS:Edit on the zone, and Account:Cloudflare Tunnel:Edit."
  type        = string
  sensitive   = true
  default     = ""
}

variable "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client ID used to provision tailnet auth keys (scope: auth_keys)."
  type        = string
  default     = ""
}

variable "tailscale_oauth_client_secret" {
  description = "Tailscale OAuth client secret."
  type        = string
  sensitive   = true
  default     = ""
}
