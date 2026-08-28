variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "db_identifier" {
  type    = string
  default = "oficina-db"
}

variable "db_name" {
  type    = string
  default = "oficina"
}

variable "db_username" {
  type    = string
  default = "oficina"
}

variable "db_instance_class" {
  description = "db.t3.micro é elegível ao free tier de 12 meses em contas novas."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage_gb" {
  type    = number
  default = 20
}

variable "postgres_engine_version" {
  type    = string
  default = "16.4"
}

# --- Publicados pelo oficina-infra-k8s ---

variable "ssm_vpc_id_param" {
  type    = string
  default = "/oficina/vpc_id"
}

variable "ssm_private_subnet_ids_param" {
  type    = string
  default = "/oficina/private_subnet_ids"
}

variable "ssm_vpc_cidr_param" {
  type    = string
  default = "/oficina/vpc_cidr"
}
