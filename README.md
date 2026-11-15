# oficina-infra-db

Terraform: banco de dados gerenciado (**Amazon RDS PostgreSQL**) — repositório 3 de 4
do Tech Challenge Fase 3. Aplique **depois** do `oficina-infra-k8s` (lê a VPC/subnets
que ele publica no SSM Parameter Store) e **antes** do `oficina-lambda-auth` (que lê o
endpoint/credenciais publicados aqui).

## Por que RDS PostgreSQL gerenciado

Mesma justificativa relacional das Fases 1/2 (transações ACID para a baixa de
estoque), mais o motivo específico da Fase 3: backups automáticos, patching e failover
sem operação manual. Alternativas consideradas (Aurora Serverless v2, DynamoDB,
self-hosted no EKS) em `docs/rfc/` no repositório principal.

## ⚠️ Custo

`db.t3.micro` é elegível ao **free tier de 12 meses** em contas AWS novas. Fora do free
tier, gira em torno de US$ 0,017/h + armazenamento (20GB gp3). Rode `terraform destroy`
quando o ambiente não estiver em uso para não manter custo ocioso.

## Diagrama

```mermaid
flowchart LR
    K8S["oficina-infra-k8s<br/>(repo 2)"] -->|"SSM: vpc_id,<br/>private_subnet_ids, vpc_cidr"| DB

    subgraph DB["oficina-infra-db (este repo)"]
        SG["aws_security_group.db<br/>(libera 5432 só na VPC)"]
        SUBG["aws_db_subnet_group.this"]
        RDS[("aws_db_instance.this<br/>PostgreSQL 16, db.t3.micro")]
        SG --> RDS
        SUBG --> RDS
    end

    DB -->|"SSM: db_endpoint,<br/>db_username, db_password"| Lambda["oficina-lambda-auth<br/>(repo 1)"]
    DB -->|"SSM: db_endpoint,<br/>db_username, db_password"| App["oficina-tech-challenge<br/>(repo 4, deploy no EKS)"]
```

## Como aplicar

```bash
terraform init
terraform apply
```

## Recursos criados

| Recurso | Descrição |
|---|---|
| `aws_db_subnet_group.this` | Usa as subnets privadas publicadas pelo `oficina-infra-k8s` |
| `aws_security_group.db` | Libera 5432 apenas para o CIDR da VPC (EKS e Lambda) |
| `aws_db_instance.this` | RDS PostgreSQL 16, `db.t3.micro`, não publicamente acessível |
| `random_password.db_password` | Senha mestra gerada aleatoriamente |
| `aws_ssm_parameter.*` | Publica endpoint/credenciais para `oficina-lambda-auth` e o deploy do app principal |

## Fase 4 — bancos por microsserviço (mesma instância, compartilhada)

Em vez de uma instância RDS por microsserviço (triplicaria o custo), o `oficina-os-service` e o `oficina-producao-service` compartilham **esta mesma instância**, cada um com seu próprio banco lógico e sua própria *role* — nunca o usuário mestre acima, e nenhum dos dois pode acessar o banco do outro.

Como a instância é privada (`publicly_accessible = false`), o runner do GitHub Actions não alcança o Postgres diretamente pra criar esses bancos/roles. O job `apply` do `ci-cd.yml` resolve isso rodando um pod efêmero **dentro do EKS** (mesma VPC, então alcança o RDS normalmente) que executa o SQL de bootstrap via `psql` — mesmo padrão já usado pro `seed-admin` nos repositórios de aplicação.

| Recurso novo | Descrição |
|---|---|
| `random_password.os_db_password` / `producao_db_password` | Senhas próprias de cada *role* |
| `aws_ssm_parameter.os_db_*` / `producao_db_*` | Publicados pra cada serviço ler no próprio `deploy-eks` |

## Modelo de dados

O schema de cada serviço é criado pela própria aplicação (`synchronize`/TypeORM na
primeira execução). O diagrama ER e a explicação dos relacionamentos do monólito da
Fase 3 ficam em `docs/database/` no repositório `oficina-tech-challenge`.

## Destruir

```bash
terraform destroy
```
