---

# `README.md`

RAG Pipeline Terraform
Infraestrutura como Código para Aplicações RAG com Streamlit na AWS

---

[![Terraform](https://img.shields.io/badge/Terraform-v1.0%2B-7B42BC?style=for-the-badge&logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EC2%20Spot-FF9900?style=for-the-badge&logo=amazon-aws)](https://aws.amazon.com/)
[![Python](https://img.shields.io/badge/Python-3.9%2B-3776AB?style=for-the-badge&logo=python)](https://www.python.org/)
[![Streamlit](https://img.shields.io/badge/Streamlit-App-FF4B4B?style=for-the-badge&logo=streamlit)](https://streamlit.io/)
[![OpenAI](https://img.shields.io/badge/OpenAI-GPT--4o%20mini-000000?style=for-the-badge&logo=openai)](https://openai.com/)

---

## 1. Visão Geral do Projeto

Este projeto implementa uma infraestrutura robusta e escalável na AWS utilizando **Terraform** para hospedar uma aplicação de **RAG (Retrieval-Augmented Generation)** baseada em **Streamlit**. A solução foi projetada para ser eficiente em custos, utilizando **instâncias EC2 Spot**, e segura, com acesso via **AWS Systems Manager (SSM)** e gerenciamento de segredos via **AWS Secrets Manager**.

O modelo de linguagem grande (LLM) utilizado é o **GPT-4o mini** da OpenAI, acessado via API, eliminando a necessidade de um servidor Ollama local e otimizando o uso de recursos computacionais (sem necessidade de GPU na instância EC2).

### Detalhes do Projeto:

-   **Nome:** `rag-pipeline-terraform`
-   **Propósito:** Provisionar e configurar a infraestrutura para uma aplicação RAG com Streamlit.
-   **LLM:** GPT-4o mini (via API OpenAI)
-   **Stack:** AWS EC2 Spot, Terraform, Python/Streamlit, Docling, LangChain, FAISS.
-   **Autor:** Patricia (Engenheira de Dados - Itaú)
-   **Região AWS:** `us-east-1`

---

## 2. Arquitetura da Solução

A arquitetura proposta visa um ambiente de desenvolvimento/teste eficiente e seguro, com foco em custos e operacionalização.

┌┐
│           USUÁRIO (Browser)             │
│         Acesso: IP/32 (8501)            │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│      AWS SECURITY GROUP (8501)          │
│    Ingress: CIDR do usuário apenas      │
│    Egress: All traffic                  │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│      EC2 SPOT INSTANCE (t3.xlarge)      │
│  ┌─────────────────────────────────┐    │
│  │  Ubuntu 22.04 LTS               │    │
│  │  ┌─────────────────────────┐    │    │
│  │  │  Streamlit Service      │    │    │
│  │  │  (Porta 8501)           │    │    │
│  │  │  ┌─────────────────┐    │    │    │
│  │  │  │  chat_stream.py │    │    │    │
│  │  │  │  ├─ Docling     │    │    │    │
│  │  │  │  ├─ LangChain   │    │    │    │
│  │  │  │  ├─ FAISS       │    │    │    │
│  │  │  │  └─ OpenAI API  │    │    │    │
│  │  │  └─────────────────┘    │    │    │
│  │  └─────────────────────────┘    │    │
│  │                                 │    │
│  │  /mnt/instance-store (NVMe)     │    │
│  │  ├── uploads/   (documentos)    │    │
│  │  ├── vectors/   (índices FAISS) │    │
│  │  └── chat_history.db (SQLite)   │    │
│  └─────────────────────────────────┘    │
│                                         │
│  IAM Role: SSM + Secrets Manager + S3   │
└┘
                  │
┌─────────────────▼───────────────────────┐
│      AWS SERVIÇOS INTEGRADOS            │
│  ├─ Secrets Manager (OpenAI API Key)    │
│  ├─ S3 (documentos para ingestão)       │
│  ├─ CloudWatch Logs                     │
│  └─ Systems Manager (SSM)               │
└┘

---

## 3. Estrutura de Diretórios

A organização do projeto segue uma estrutura modular para promover reuso e clareza.

```
rag-pipeline-terraform/
├── main.tf                    # Orquestrador principal: define a infraestrutura usando os módulos.
├── variables.tf               # Variáveis globais do projeto.
├── outputs.tf                 # Saídas importantes do deploy (IP, URL, comandos SSM).
├── terraform.tfvars           # Valores específicos para as variáveis (NÃO VERSIONAR!).
├── versions.tf                # Define as versões mínimas do Terraform e dos providers.
├── README.md                  # Este arquivo de documentação.
├── modules/                   # Contém os módulos Terraform reutilizáveis.
│   ├── ec2-spot/              # Módulo para provisionar instâncias EC2 Spot.
│   │   ├── main.tf            # Define o recurso aws_instance.
│   │   ├── variables.tf       # Variáveis de configuração do módulo EC2.
│   │   └── outputs.tf         # Saídas do módulo EC2.
│   ├── iam-ssm/               # Módulo para criar IAM Role e Instance Profile com permissões SSM e outras.
│   │   ├── main.tf            # Define os recursos IAM.
│   │   ├── variables.tf       # Variáveis de configuração do módulo IAM.
│   │   └── outputs.tf         # Saídas do módulo IAM.
│   └── security-group/        # Módulo para criar Security Groups parametrizáveis.
│       ├── main.tf            # Define o recurso aws_security_group e suas regras.
│       ├── variables.tf       # Variáveis de configuração do módulo SG.
│       └── outputs.tf         # Saídas do módulo SG.
└── templates/                 # Contém templates de scripts para user_data.
    └── user_data.sh           # Script de bootstrap para configurar a instância EC2.
```

---

## 4. Pré-requisitos

Antes de iniciar o deploy, certifique-se de ter as seguintes ferramentas instaladas e configuradas:

-   **AWS CLI:** Configurado com credenciais de acesso à sua conta AWS na região `us-east-1`.
    -   [Instalação AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
    -   [Configuração AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)
-   **Terraform:** Versão `v1.0.0` ou superior.
    -   [Instalação Terraform](https://developer.hashicorp.com/terraform/downloads)
-   **Git:** Para clonar o repositório da aplicação.
    -   [Instalação Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

2.  **Atualize seu `chat_stream.py`:**
    Certifique-se de que sua aplicação Python leia a chave da API da variável de ambiente `OPENAI_API_KEY`. O script `user_data.sh` se encarregará de carregar essa variável do Secrets Manager antes de iniciar a aplicação.

    Exemplo de como sua aplicação deve ler a chave:
    ```python
    import os
    from openai import OpenAI

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY não configurada no ambiente.")
    client = OpenAI(api_key=api_key)
    ```

---

## 5. Configuração (`terraform.tfvars`)

O arquivo `terraform.tfvars` contém os valores específicos para as variáveis do seu ambiente. **Este arquivo não deve ser versionado no Git** por conter informações sensíveis ou específicas do ambiente.

Crie um arquivo chamado `terraform.tfvars` na raiz do projeto com o seguinte conteúdo, substituindo os valores pelos seus:

```hcl
# 
# CONFIGURAÇÃO DE EXEMPLO - Dev Environment
# 

environment = "dev"
project_name = "rag-pipeline"
region = "us-east-1"

# ⚠️ IMPORTANTE: Substitua pelo seu IP público atual
# Descubra em: https://checkip.amazonaws.com
# Formato: "xxx.xxx.xxx.xxx/32"
allowed_cidr = "201.42.201.230/32"

# Compute - CPU-only suficiente para GPT-4o mini via API
# Para dev/teste com Docling + FAISS, recomendo t3.xlarge ou t3.2xlarge
instance_type = "t3.xlarge"
spot_max_price = "0.15"  # Preço máximo para Spot (null = preço on-demand)

# Storage
root_volume_size = 30 # Aumentado para acomodar modelos de embedding e índices FAISS

# Aplicação
app_git_repo    = "https://github.com/patyid/chatbot-project.git"
app_git_branch  = "main"
app_dir_name    = "chatbot-app"
app_entry_point = "chat_stream.py"
app_port        = 8501

# S3 para documentos RAG (se enable_s3_access for true)
enable_s3_access = true
s3_bucket_arns = [
  "arn:aws:s3:::rag-documents-dev-452271769418" # Substitua pelo ARN do seu bucket
]

# Monitoramento
enable_detailed_monitoring = false # Habilitar monitoramento detalhado do CloudWatch
log_retention_days = 7 # Dias de retenção dos logs no CloudWatch
```

---

## 6. Como Usar (Comandos de Deploy)

Siga os passos abaixo para provisionar sua infraestrutura:

1.  **Clone o repositório:**
    ```bash
    git clone 
    cd rag-pipeline-terraform
    ```

2.  **Inicialize o Terraform:**
    Este comando baixa os providers necessários e configura o backend S3.
    ```bash
    terraform init
    ```

3.  **Valide a configuração:**
    Verifica a sintaxe e a validade dos arquivos Terraform.
    ```bash
    terraform validate
    ```

4.  **Planeje as mudanças:**
    Mostra um plano detalhado dos recursos que serão criados, modificados ou destruídos.
    ```bash
    terraform plan -var-file="terraform.tfvars"
    ```

5.  **Aplique as mudanças:**
    Executa o plano e provisiona os recursos na AWS.
    ```bash
    terraform apply -var-file="terraform.tfvars" -auto-approve
    ```
    Após a aplicação, o Terraform exibirá os `outputs` configurados, incluindo a URL da sua aplicação Streamlit e o comando SSM para acesso.

6.  **Destrua a infraestrutura (quando não for mais necessária):**
    **CUIDADO:** Este comando removerá **TODOS** os recursos provisionados pelo Terraform.
    ```bash
    terraform destroy -var-file="terraform.tfvars" -auto-approve
    ```

---

## 7. Módulos Disponíveis

Este projeto utiliza módulos Terraform customizados para promover reuso e organização.

### 7.1. `modules/ec2-spot`

-   **Propósito:** Provisiona uma instância EC2 Spot com configurações flexíveis.
-   **Características:**
    -   Seleção de AMI (Ubuntu 22.04 LTS por padrão).
    -   Configuração de tipo de instância, IAM Instance Profile, Security Groups e Subnet.
    -   Opções de Spot Instance (one-time, persistent, comportamento de interrupção, preço máximo).
    -   Configuração detalhada do volume raiz (tamanho, tipo, criptografia).
    -   Suporte a `user_data` para bootstrap da instância.
    -   IMDSv2 obrigatório para maior segurança.
-   **Uso:** Utilizado para criar a instância que hospeda a aplicação Streamlit.

### 7.2. `modules/iam-ssm`

-   **Propósito:** Cria uma IAM Role e um IAM Instance Profile para instâncias EC2, com foco em acesso via SSM e permissões para serviços AWS essenciais.
-   **Características:**
    -   Anexa a política gerenciada `AmazonSSMManagedInstanceCore`.
    -   Permissões para `AWS Secrets Manager` (para chaves de API, ex: OpenAI).
    -   Permissões para `AWS Systems Manager Parameter Store` (para configurações).
    -   Permissões opcionais para `AWS S3` (para acesso a documentos RAG).
    -   Permissões opcionais para `AWS CloudWatch Logs` (para monitoramento de logs).
-   **Uso:** Atribuído à instância EC2 para permitir gerenciamento via SSM e acesso seguro a outros serviços AWS.

### 7.3. `modules/security-group`

-   **Propósito:** Cria um Security Group (SG) parametrizável com regras de ingress e egress dinâmicas.
-   **Características:**
    -   Definição flexível de regras de entrada (ingress) por porta, protocolo e CIDR/Security Group de origem.
    -   Definição flexível de regras de saída (egress) por porta, protocolo e CIDR/Security Group de destino.
    -   Regra de egress padrão para permitir todo o tráfego de saída (`0.0.0.0/0`).
-   **Uso:** Controla o tráfego de rede para a instância EC2, permitindo acesso à aplicação Streamlit apenas do CIDR especificado.

---

## 8. Comandos Úteis para Debug

Após o deploy, você pode usar os seguintes comandos para verificar o status da sua aplicação e da instância.

### 8.1. Acesso à Instância via SSM

```bash
aws ssm start-session --target $(terraform output -raw instance_id) --region us-east-1
```

### 8.2. Verificar Logs do User Data

```bash
aws ssm send-command \
  --instance-ids $(terraform output -raw instance_id) \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["sudo tail -100 /var/log/user-data.log"]' \
  --region us-east-1 \
  --query "Command.CommandId" --output text
# Para ver o output do comando:
# aws ssm list-command-invocations --command-id  --details --query "CommandInvocations[0].CommandPlugins[0].Output" --output text --region us-east-1
```

### 8.3. Verificar Status do Cloud-init

```bash
aws ssm send-command \
  --instance-ids $(terraform output -raw instance_id) \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["sudo cloud-init status --long"]' \
  --region us-east-1 \
  --query "Command.CommandId" --output text
```

### 8.4. Verificar Status do Serviço Streamlit

```bash
aws ssm send-command \
  --instance-ids $(terraform output -raw instance_id) \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["sudo systemctl status streamlit"]' \
  --region us-east-1 \
  --query "Command.CommandId" --output text
```

### 8.5. Acessar Logs da Aplicação no CloudWatch

```bash
aws logs tail /aws/ec2/rag-pipeline-dev --follow --region us-east-1
```

---

## 9. Troubleshooting

### 9.1. Instância não inicia ou entra em estado `pending` por muito tempo

-   **Verificar quota de Spot:** Você pode ter atingido o limite de instâncias Spot.
    ```bash
    aws ec2 describe-spot-instance-requests --region us-east-1
    ```
-   **Verificar disponibilidade na AZ:** O tipo de instância pode não estar disponível na AZ selecionada.
    ```bash
    aws ec2 describe-instance-type-offerings \
      --location-type availability-zone \
      --filters Name=instance-type,Values=t3.xlarge \
      --region us-east-1
    ```

### 9.2. Aplicação Streamlit não acessível via navegador

-   **Verificar Security Group:** Certifique-se de que seu IP público (`allowed_cidr`) está correto e que a porta 8501 está aberta.
-   **Verificar serviço Streamlit:** Use os comandos de debug acima para verificar se o serviço `streamlit` está ativo na instância.
-   **Verificar logs da aplicação:** Use o comando `aws logs tail` ou acesse via SSM para verificar `/var/log/streamlit.log` e `/var/log/user-data.log` para erros.

### 9.3. Erro de permissão ao acessar S3 ou Secrets Manager

-   **Verificar IAM Role:** Confirme se a IAM Role (`rag-pipeline-dev-role`) anexada à instância possui as permissões corretas para `s3:GetObject`, `secretsmanager:GetSecretValue`, etc.
-   **Testar permissões manualmente via SSM:**
    ```bash
    # Dentro da sessão SSM
    aws sts get-caller-identity
    aws secretsmanager get-secret-value --secret-id /rag-pipeline/openai-api-key --query SecretString --output text
    aws s3 ls s3://rag-documents-dev-452271769418/
    ```

### 9.4. Erro de `OPENAI_API_KEY` não encontrada na aplicação

-   **Verificar Secret Manager:** Confirme se o secret `/rag-pipeline/openai-api-key` existe e contém o valor correto.
-   **Verificar script `load_secrets.sh`:** Acesse a instância via SSM e verifique o conteúdo e a execução de `/opt/app/load_secrets.sh`.
-   **Verificar logs do Streamlit:** O log da aplicação (`/var/log/streamlit.log`) pode indicar se a variável de ambiente foi carregada.

---

## 10. Segurança

A segurança é um pilar fundamental deste projeto, com as seguintes práticas implementadas:

-   **IMDSv2 Obrigatório:** O Instance Metadata Service Version 2 (IMDSv2) é exigido para todas as requisições de metadados da instância, prevenindo vulnerabilidades de SSRF (Server-Side Request Forgery).
-   **Criptografia de Volume Raiz:** O volume EBS raiz da instância é criptografado por padrão, protegendo os dados em repouso.
-   **Security Group Restritivo:** O acesso à aplicação Streamlit (porta 8501) é restrito ao seu IP público (`allowed_cidr`), minimizando a superfície de ataque.
-   **Sem Chave SSH:** O acesso à instância é feito exclusivamente via AWS Systems Manager (SSM), eliminando a necessidade de chaves SSH e reduzindo riscos de acesso não autorizado.
-   **Manager Parameter Store para Credenciais:** Chaves de API sensíveis (como a da OpenAI) são armazenadas e acessadas via AWS Parameter Store, evitando hardcoding e exposição.
-   **IAM Least Privilege:** As permissões da IAM Role são configuradas com o princípio do menor privilégio, concedendo apenas o acesso necessário aos serviços AWS.
-   **Logs Centralizados:** Logs do `user_data`, `cloud-init` e da aplicação Streamlit são enviados para o AWS CloudWatch Logs, facilitando monitoramento, auditoria e troubleshooting.

---
## 11. Custos Estimados

Os custos são uma estimativa para um ambiente de desenvolvimento/teste na região `us-east-1` com uso moderado.

| **S3** | Armazenamento de documentos RAG | Variável (ex: ~$0.023/GB) |
| **CloudWatch Logs** | Ingestão e armazenamento de logs | ~$0.50 - $2.00 (dependendo do volume) |
| **EBS (gp3)** | Volume raiz de 30GB | ~$2.40 |
| **Total Estimado** | | **~$40 - $60+** (excluindo custo da API OpenAI) |

> **Nota:** A maior parte do custo vem da instância EC2. O uso de instâncias Spot oferece uma economia significativa em comparação com instâncias On-Demand.

---
