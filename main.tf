# ATENÇÃO — CUSTO REAL (embora modesto): db.t3.micro é elegível ao free tier
# de 12 meses em contas AWS novas; fora do free tier, gira em torno de
# US$ 0,017/h + armazenamento. Rode `terraform destroy` depois da demonstração.
#
# Lê a VPC/subnets publicadas pelo oficina-infra-k8s — aplique-o primeiro.

data "aws_ssm_parameter" "vpc_id" {
  name = var.ssm_vpc_id_param
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = var.ssm_private_subnet_ids_param
}

data "aws_ssm_parameter" "vpc_cidr" {
  name = var.ssm_vpc_cidr_param
}

locals {
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
}

resource "random_password" "db_password" {
  length  = 24
  special = false # evita caracteres que a engine do RDS rejeita na senha mestra
}

# --- Fase 4: cada microsserviço tem sua própria role/banco lógico nesta
# mesma instância (compartilhada para conter custo), nunca o usuário
# mestre acima — ver docs/adr sobre a decisão de 1 instância compartilhada.
resource "random_password" "os_db_password" {
  length  = 24
  special = false
}

resource "random_password" "producao_db_password" {
  length  = 24
  special = false
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.db_identifier}-subnet-group"
  subnet_ids = local.private_subnet_ids
}

resource "aws_security_group" "db" {
  name_prefix = "${var.db_identifier}-"
  description = "Permite Postgres (5432) apenas de dentro da VPC (EKS e Lambda)"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  ingress {
    description = "Postgres a partir de qualquer recurso na VPC (EKS, Lambda)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_ssm_parameter.vpc_cidr.value]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "this" {
  identifier     = var.db_identifier
  engine         = "postgres"
  engine_version = var.postgres_engine_version
  instance_class = var.db_instance_class

  allocated_storage      = var.db_allocated_storage_gb
  storage_type           = "gp3"
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]

  publicly_accessible = false
  multi_az            = false # custo menor; produção real usaria multi_az = true
  skip_final_snapshot = true  # simplifica o destroy neste contexto de demonstração/estudo
  deletion_protection = false

  backup_retention_period = 1
}

# --- Publica o que os outros repositórios precisam ---

resource "aws_ssm_parameter" "db_endpoint" {
  name      = "/oficina/db_endpoint"
  type      = "String"
  value     = aws_db_instance.this.address
  overwrite = true
}

resource "aws_ssm_parameter" "db_name" {
  name      = "/oficina/db_name"
  type      = "String"
  value     = var.db_name
  overwrite = true
}

resource "aws_ssm_parameter" "db_username" {
  name      = "/oficina/db_username"
  type      = "SecureString"
  value     = var.db_username
  overwrite = true
}

resource "aws_ssm_parameter" "db_password" {
  name      = "/oficina/db_password"
  type      = "SecureString"
  value     = random_password.db_password.result
  overwrite = true
}

# --- Fase 4: credenciais por microsserviço (roles criadas pelo job
# create-service-dbs no ci-cd.yml, não pelo provider do AWS/Terraform —
# a instância é privada, o runner do GitHub Actions não a alcança
# diretamente; o job roda de dentro do EKS, que está na mesma VPC) ---

resource "aws_ssm_parameter" "os_db_name" {
  name      = "/oficina/os_db_name"
  type      = "String"
  value     = var.os_db_name
  overwrite = true
}

resource "aws_ssm_parameter" "os_db_username" {
  name      = "/oficina/os_db_username"
  type      = "SecureString"
  value     = var.os_db_username
  overwrite = true
}

resource "aws_ssm_parameter" "os_db_password" {
  name      = "/oficina/os_db_password"
  type      = "SecureString"
  value     = random_password.os_db_password.result
  overwrite = true
}

resource "aws_ssm_parameter" "producao_db_name" {
  name      = "/oficina/producao_db_name"
  type      = "String"
  value     = var.producao_db_name
  overwrite = true
}

resource "aws_ssm_parameter" "producao_db_username" {
  name      = "/oficina/producao_db_username"
  type      = "SecureString"
  value     = var.producao_db_username
  overwrite = true
}

resource "aws_ssm_parameter" "producao_db_password" {
  name      = "/oficina/producao_db_password"
  type      = "SecureString"
  value     = random_password.producao_db_password.result
  overwrite = true
}
