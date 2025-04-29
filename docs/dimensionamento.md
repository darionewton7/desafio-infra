# Dimensionamento de Recursos

## Introdução

Este documento detalha o dimensionamento de recursos para a solução híbrida da XPTO Finance, considerando os requisitos de alta disponibilidade, escalabilidade e otimização de custos. O dimensionamento foi projetado para suportar a carga atual e futura, com capacidade de escalar durante picos de demanda.

## Requisitos de Carga

- **Serviço de Consolidado Diário**: 50 requisições por segundo em picos, com máximo de 5% de perda
- **Serviço de Lançamentos Financeiros**: Deve manter disponibilidade mesmo quando o serviço de consolidado estiver indisponível
- **Picos de Acesso**: Períodos promocionais com aumento significativo de tráfego

## Estratégia de Dimensionamento

### Modelo de Escalabilidade

A solução adota uma abordagem híbrida de escalabilidade:

- **Escalabilidade Horizontal**: Primária para serviços em contêineres e aplicações stateless
- **Escalabilidade Vertical**: Utilizada para bancos de dados e componentes stateful

### Ambiente On-Premises

#### Servidores de Aplicação

| Recurso | Mínimo | Recomendado | Justificativa |
|---------|--------|-------------|---------------|
| CPU | 8 cores | 16 cores | Suportar processamento de transações financeiras |
| Memória | 16 GB | 32 GB | Cache de aplicação e processamento em memória |
| Armazenamento | 500 GB SSD | 1 TB SSD | Logs, arquivos temporários e cache local |
| Quantidade | 2 | 4 | Alta disponibilidade com N+1 redundância |

#### Banco de Dados PostgreSQL

| Recurso | Mínimo | Recomendado | Justificativa |
|---------|--------|-------------|---------------|
| CPU | 16 cores | 32 cores | Processamento de consultas complexas |
| Memória | 64 GB | 128 GB | Cache de dados e índices |
| Armazenamento | 2 TB SSD | 4 TB SSD | Dados transacionais e históricos |
| IOPS | 5.000 | 10.000 | Garantir performance em picos de escrita |
| Quantidade | 2 (Master/Slave) | 3 (1 Master, 2 Slaves) | Alta disponibilidade e distribuição de leitura |

#### Load Balancers

| Recurso | Mínimo | Recomendado | Justificativa |
|---------|--------|-------------|---------------|
| CPU | 4 cores | 8 cores | Processamento de SSL e roteamento |
| Memória | 8 GB | 16 GB | Tabelas de conexão e cache SSL |
| Quantidade | 2 | 2 | Configuração ativo/ativo para HA |

### Ambiente Cloud

#### Kubernetes Cluster

| Recurso | Mínimo | Máximo | Justificativa |
|---------|--------|--------|---------------|
| Nós Worker | 3 | 10 | Escala conforme demanda |
| CPU por nó | 4 cores | 8 cores | Suportar múltiplos pods |
| Memória por nó | 16 GB | 32 GB | Múltiplos pods e overhead do sistema |
| Zonas de Disponibilidade | 2 | 3 | Distribuição geográfica para HA |

#### Serviço de Lançamentos Financeiros (Pods)

| Recurso | Mínimo | Máximo | Justificativa |
|---------|--------|--------|---------------|
| Réplicas | 3 | 10 | Escala conforme demanda |
| CPU por pod | 100m | 500m | Processamento de transações |
| Memória por pod | 256 MB | 512 MB | Cache de aplicação |
| Autoscaling | CPU > 70% | - | Escala antes de degradação |

#### Serviço de Consolidado Diário (Pods)

| Recurso | Mínimo | Máximo | Justificativa |
|---------|--------|--------|---------------|
| Réplicas | 2 | 8 | Escala conforme demanda |
| CPU por pod | 200m | 1000m | Processamento de relatórios |
| Memória por pod | 384 MB | 768 MB | Processamento em memória |
| Autoscaling | CPU > 70% | - | Escala antes de degradação |

#### Cache Redis

| Recurso | Mínimo | Recomendado | Justificativa |
|---------|--------|-------------|---------------|
| Instâncias | 2 | 3 | Configuração Master/Replica |
| Memória | 2 GB | 4 GB | Cache de sessões e dados frequentes |
| Conexões | 1.000 | 5.000 | Suportar picos de conexões |

#### Banco de Dados RDS (Réplica de Leitura)

| Recurso | Mínimo | Recomendado | Justificativa |
|---------|--------|-------------|---------------|
| CPU | 4 cores | 8 cores | Processamento de consultas |
| Memória | 16 GB | 32 GB | Cache de dados e índices |
| Armazenamento | 1 TB SSD | 2 TB SSD | Réplica dos dados on-premises |
| IOPS | 3.000 | 6.000 | Garantir performance em picos de leitura |

## Estimativas de Carga

### Serviço de Lançamentos Financeiros

- **Carga Normal**: 10-20 requisições por segundo
- **Pico de Carga**: 30-40 requisições por segundo
- **Tempo de Resposta Alvo**: < 200ms para 95% das requisições
- **Throughput de Dados**: ~5 KB por requisição

### Serviço de Consolidado Diário

- **Carga Normal**: 5-10 requisições por segundo
- **Pico de Carga**: 50 requisições por segundo
- **Tempo de Resposta Alvo**: < 500ms para 95% das requisições
- **Throughput de Dados**: ~20 KB por requisição

## Estratégia de Ajuste Dinâmico

Para otimizar custos e performance, a solução implementa:

1. **Autoscaling Baseado em Métricas**:
   - Escala horizontal baseada em utilização de CPU e memória
   - Políticas de escala diferentes para cada serviço

2. **Ajuste de Recursos por Período**:
   - Aumento de capacidade em horários de pico conhecidos
   - Redução de capacidade em períodos de baixa utilização

3. **Monitoramento Preditivo**:
   - Análise de tendências para prever necessidades futuras
   - Ajuste proativo de recursos antes de picos esperados

## Considerações para Picos de Demanda

Durante períodos promocionais ou de alta demanda, a arquitetura está preparada para:

1. **Escala Rápida**: Políticas de autoscaling agressivas para o serviço de consolidado
2. **Priorização de Tráfego**: QoS para garantir que o serviço de lançamentos não seja afetado
3. **Cache Avançado**: Aumento temporário da capacidade de cache
4. **Throttling Inteligente**: Limitação de taxa para clientes não prioritários

## Conclusão

O dimensionamento proposto garante que a solução atenda aos requisitos de carga atuais e futuros, com capacidade de escalar durante picos de demanda. A abordagem híbrida de escalabilidade, combinada com políticas de autoscaling e monitoramento preditivo, permite otimizar custos sem comprometer a performance e disponibilidade dos serviços.
