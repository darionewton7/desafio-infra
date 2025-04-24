# Terraform para provisionamento da infraestrutura híbrida XPTO Finance
# Autor: Dário Newton
# Data: Abril 2025

# Configuração do provedor AWS (exemplo com custo zero usando localstack)
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # Usando LocalStack para desenvolvimento local sem custos
  # Em produção, remover estas linhas e configurar credenciais reais
  endpoints {
    apigateway     = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    iam            = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    rds            = "http://localhost:4566"
    s3             = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    sqs            = "http://localhost:4566"
  }
}

# Configuração do provedor Kubernetes (Minikube para desenvolvimento local)
provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Configuração do provedor Helm para instalação de charts
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# VPC para ambiente cloud
resource "aws_vpc" "xpto_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "xpto-vpc"
    Environment = "production"
    Project     = "xpto-finance"
  }
}

# Subnets públicas (para balanceadores e gateways)
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.xpto_vpc.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = "us-east-1${count.index == 0 ? "a" : "b"}"

  tags = {
    Name        = "xpto-public-subnet-${count.index + 1}"
    Environment = "production"
    Project     = "xpto-finance"
  }
}

# Subnets privadas (para serviços e bancos de dados)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.xpto_vpc.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = "us-east-1${count.index == 0 ? "a" : "b"}"

  tags = {
    Name        = "xpto-private-subnet-${count.index + 1}"
    Environment = "production"
    Project     = "xpto-finance"
  }
}

# Internet Gateway para acesso externo
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.xpto_vpc.id

  tags = {
    Name        = "xpto-igw"
    Environment = "production"
    Project     = "xpto-finance"
  }
}

# NAT Gateway para acesso à internet das subnets privadas
resource "aws_nat_gateway" "nat" {
  count         = 1 # Usando apenas 1 para redução de custos
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "xpto-nat-gateway-${count.index + 1}"
    Environment = "production"
    Project     = "xpto-finance"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Elastic IP para o NAT Gateway
resource "aws_eip" "nat" {
  count = 1 # Usando apenas 1 para redução de custos
  vpc   = true

  tags = {
    Name        = "xpto-eip-${count.index + 1}"
    Environment = "production"
    Project     = "xpto-finance"
  }
}

# Tabela de rotas para subnets públicas
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.xpto_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "xpto-public-route-table"
    Environment = "production"
    Project     = "xpto-finance"
  }
}

# Tabela de rotas para subnets privadas
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.xpto_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[0].id
  }

  tags = {
    Name        = "xpto-private-route-table"
    Environment = "production"
    Project     = "xpto-finance"
  }
}

# Associação de tabelas de rotas às subnets públicas
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associação de tabelas de rotas às subnets privadas
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Grupo de segurança para API Gateway
resource "aws_security_group" "api_gateway" {
  name        = "xpto-api-gateway-sg"
  description = "Security group for API Gateway"
  vpc_id      = aws_vpc.xpto_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "xpto-api-gateway-sg"
    Environment = "production"
    Project     = "xpto-finance"
  }
}

# Grupo de segurança para Kubernetes
resource "aws_security_group" "kubernetes" {
  name        = "xpto-kubernetes-sg"
  description = "Security group for Kubernetes cluster"
  vpc_id      = aws_vpc.xpto_vpc.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.api_gateway.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "xpto-kubernetes-sg"
    Environment = "production"
    Project     = "xpto-finance"
  }
}

# Grupo de segurança para RDS
resource "aws_security_group" "database" {
  name        = "xpto-database-sg"
  description = "Security group for RDS instances"
  vpc_id      = aws_vpc.xpto_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.kubernetes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "xpto-database-sg"
    Environment = "production"
    Project     = "xpto-finance"
  }
}

# Grupo de segurança para ElastiCache (Redis)
resource "aws_security_group" "cache" {
  name        = "xpto-cache-sg"
  description = "Security group for ElastiCache instances"
  vpc_id      = aws_vpc.xpto_vpc.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.kubernetes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "xpto-cache-sg"
    Environment = "production"
    Project     = "xpto-finance"
  }
}

# Grupo de segurança para VPN Gateway
resource "aws_security_group" "vpn" {
  name        = "xpto-vpn-sg"
  description = "Security group for VPN Gateway"
  vpc_id      = aws_vpc.xpto_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Em produção, restringir para IPs específicos
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "xpto-vpn-sg"
    Environment = "production"
    Project     = "xpto-finance"
  }
}

# Definição de outputs para uso em outros módulos ou scripts
output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.xpto_vpc.id
}

output "public_subnet_ids" {
  description = "IDs das subnets públicas"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = aws_subnet.private[*].id
}

output "api_gateway_sg_id" {
  description = "ID do grupo de segurança do API Gateway"
  value       = aws_security_group.api_gateway.id
}

output "kubernetes_sg_id" {
  description = "ID do grupo de segurança do Kubernetes"
  value       = aws_security_group.kubernetes.id
}

output "database_sg_id" {
  description = "ID do grupo de segurança do banco de dados"
  value       = aws_security_group.database.id
}

output "cache_sg_id" {
  description = "ID do grupo de segurança do cache"
  value       = aws_security_group.cache.id
}

output "vpn_sg_id" {
  description = "ID do grupo de segurança da VPN"
  value       = aws_security_group.vpn.id
}
