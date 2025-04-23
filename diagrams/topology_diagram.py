#!/usr/bin/env python3
from diagrams import Diagram, Cluster, Edge
from diagrams.onprem.compute import Server
from diagrams.onprem.database import PostgreSQL
from diagrams.onprem.network import Internet, Nginx
from diagrams.onprem.network import Haproxy
from diagrams.onprem.storage import Ceph
from diagrams.onprem.monitoring import Grafana, Prometheus
from diagrams.onprem.security import Vault
from diagrams.k8s.compute import Pod, Deployment
from diagrams.k8s.network import Service, Ingress
from diagrams.k8s.storage import PV
from diagrams.aws.compute import Lambda
from diagrams.aws.database import RDS, ElastiCache
from diagrams.aws.network import VPC, DirectConnect, VpnGateway, APIGateway
from diagrams.aws.storage import S3
from diagrams.aws.integration import SQS
from diagrams.aws.security import WAF
from diagrams.aws.management import Cloudwatch

# Configuração do diagrama
graph_attr = {
    "fontsize": "20",
    "bgcolor": "white",
    "rankdir": "TB",
    "splines": "spline",
}

# Criação do diagrama principal
with Diagram("Arquitetura Híbrida XPTO Finance", show=False, outformat="png", filename="topologia", graph_attr=graph_attr):
    
    # Internet e usuários
    internet = Internet("Usuários")
    
    # WAF e API Gateway
    with Cluster("Camada de Entrada"):
        waf = WAF("WAF")
        api = APIGateway("API Gateway")
        internet >> waf >> api
    
    # Ambiente Cloud
    with Cluster("Ambiente Cloud"):
        # VPC
        with Cluster("VPC"):
            # Kubernetes Cluster
            with Cluster("Kubernetes Cluster"):
                # Serviço de Lançamentos
                with Cluster("Serviço de Lançamentos"):
                    lancamentos_pods = [Pod("Pod 1"), Pod("Pod 2"), Pod("Pod 3")]
                    lancamentos_service = Service("Lançamentos Service")
                    lancamentos_deployment = Deployment("Lançamentos Deployment")
                    
                    for pod in lancamentos_pods:
                        lancamentos_deployment >> pod
                        pod >> lancamentos_service
                
                # Serviço de Consolidado Diário
                with Cluster("Serviço de Consolidado Diário"):
                    consolidado_pods = [Pod("Pod 1"), Pod("Pod 2")]
                    consolidado_service = Service("Consolidado Service")
                    consolidado_deployment = Deployment("Consolidado Deployment")
                    
                    for pod in consolidado_pods:
                        consolidado_deployment >> pod
                        pod >> consolidado_service
                
                # Ingress Controller
                ingress = Ingress("Ingress Controller")
                
                # Conexões
                api >> ingress
                ingress >> lancamentos_service
                ingress >> consolidado_service
            
            # Serviços Serverless
            with Cluster("Serviços Serverless"):
                lambda_proc = Lambda("Processamento Assíncrono")
                sqs = SQS("Fila de Mensagens")
                
                lancamentos_service >> sqs >> lambda_proc
            
            # Banco de Dados e Cache
            with Cluster("Dados"):
                rds_replica = RDS("RDS (Réplica)")
                elasticache = ElastiCache("Redis Cache")
                
                lancamentos_service >> elasticache
                consolidado_service >> elasticache
                
                lancamentos_service >> rds_replica
                consolidado_service >> rds_replica
                lambda_proc >> rds_replica
            
            # Monitoramento
            with Cluster("Monitoramento"):
                cloudwatch = Cloudwatch("CloudWatch")
                
                lancamentos_service - Edge(style="dotted") - cloudwatch
                consolidado_service - Edge(style="dotted") - cloudwatch
                lambda_proc - Edge(style="dotted") - cloudwatch
                rds_replica - Edge(style="dotted") - cloudwatch
                elasticache - Edge(style="dotted") - cloudwatch
    
    # Conexão Híbrida
    vpn = VpnGateway("VPN Gateway")
    direct_connect = DirectConnect("Direct Connect")
    
    # Ambiente On-Premises
    with Cluster("Ambiente On-Premises"):
        # Load Balancer
        lb = Haproxy("Load Balancer")
        
        # Servidores de Aplicação
        with Cluster("Servidores de Aplicação"):
            app_servers = [Server("App Server 1"), Server("App Server 2")]
            
            for server in app_servers:
                lb >> server
        
        # Banco de Dados
        with Cluster("Banco de Dados"):
            pg_master = PostgreSQL("PostgreSQL Master")
            pg_slave = PostgreSQL("PostgreSQL Slave")
            
            pg_master >> pg_slave
            
            for server in app_servers:
                server >> pg_master
        
        # Storage
        with Cluster("Storage"):
            san = Ceph("SAN Storage")
            
            pg_master >> san
            pg_slave >> san
        
        # Monitoramento On-Premises
        with Cluster("Monitoramento"):
            prometheus = Prometheus("Prometheus")
            grafana = Grafana("Grafana")
            
            prometheus >> grafana
            
            for server in app_servers:
                server - Edge(style="dotted") - prometheus
            
            pg_master - Edge(style="dotted") - prometheus
            pg_slave - Edge(style="dotted") - prometheus
    
    # Conexões entre ambientes
    rds_replica << vpn >> pg_master
    rds_replica << direct_connect >> pg_master
