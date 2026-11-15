output "db_endpoint" {
  value = aws_db_instance.this.address
}

output "db_identifier" {
  value = aws_db_instance.this.identifier
}

# --- Lidos pelo ci-cd.yml pra rodar o job create-service-dbs (cria as
# roles/bancos lógicos de cada microsserviço de dentro do EKS) ---

output "master_db_username" {
  value = var.db_username
}

output "master_db_password" {
  value     = random_password.db_password.result
  sensitive = true
}

output "os_db_name" {
  value = var.os_db_name
}

output "os_db_username" {
  value = var.os_db_username
}

output "os_db_password" {
  value     = random_password.os_db_password.result
  sensitive = true
}

output "producao_db_name" {
  value = var.producao_db_name
}

output "producao_db_username" {
  value = var.producao_db_username
}

output "producao_db_password" {
  value     = random_password.producao_db_password.result
  sensitive = true
}
