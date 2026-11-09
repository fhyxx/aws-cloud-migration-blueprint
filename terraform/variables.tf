variable "aws_region" {
  description = "AWS Region for the fictional portfolio environment."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix applied to network resource names."
  type        = string
  default     = "clafoke"
}

variable "vpc_cidr" {
  description = "Synthetic VPC CIDR."
  type        = string
  default     = "10.30.0.0/16"
}

variable "source_cidr" {
  description = "Synthetic on-premises aggregate advertised over the VPN."
  type        = string
  default     = "10.50.0.0/16"
}

variable "source_app_cidr" {
  description = "Synthetic source application subnet permitted to reach MGN staging."
  type        = string
  default     = "10.50.10.0/24"
}

variable "source_db_cidr" {
  description = "Synthetic PostgreSQL/NFS source subnet."
  type        = string
  default     = "10.50.20.0/24"
}

variable "app_port" {
  description = "Synthetic application listener behind the ALB."
  type        = number
  default     = 8080
}

variable "create_nat_gateways" {
  description = "Opt in to two chargeable NAT Gateways and Elastic IPs. Keep false for safe plan review."
  type        = bool
  default     = false
}

variable "enable_site_to_site_vpn" {
  description = "Opt in to chargeable Site-to-Site VPN resources. Requires a real/synthetic lab customer gateway public IP."
  type        = bool
  default     = false
}

variable "customer_gateway_ip" {
  description = "Public outside IPv4 address of the customer gateway; required only when VPN is enabled."
  type        = string
  default     = null
  nullable    = true
}

variable "customer_gateway_asn" {
  description = "Synthetic customer-side private ASN."
  type        = number
  default     = 65010
}

variable "vgw_asn" {
  description = "VGW Amazon-side ASN."
  type        = number
  default     = 64512
}

variable "tags" {
  description = "Additional resource tags."
  type        = map(string)
  default     = {}
}
