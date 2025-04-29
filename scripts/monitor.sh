#!/bin/bash
# Script de automação para monitoramento e recuperação
# Autor: Dário Newton
# Data: Abril 2025

# Configurações
LOG_FILE="/var/log/xpto-monitor.log"
ALERT_EMAIL="admin@xpto.com.br"
SLACK_WEBHOOK="https://hooks.slack.com/services/XXXXX/YYYYY/ZZZZZ"
CHECK_INTERVAL=60  # segundos
MAX_CPU_THRESHOLD=80  # porcentagem
MAX_MEM_THRESHOLD=80  # porcentagem
MAX_DISK_THRESHOLD=85  # porcentagem
SERVICES=("postgresql" "haproxy" "strongswan" "prometheus" "grafana-server")

# Função para logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Função para enviar alertas
send_alert() {
    local subject="[ALERTA] XPTO Finance - $1"
    local message="$2"
    
    # Enviar email
    echo "$message" | mail -s "$subject" $ALERT_EMAIL
    
    # Enviar para Slack
    curl -s -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"$subject\n$message\"}" \
        $SLACK_WEBHOOK
    
    log "Alerta enviado: $subject"
}

# Verificar CPU
check_cpu() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    
    if (( $(echo "$cpu_usage > $MAX_CPU_THRESHOLD" | bc -l) )); then
        send_alert "Alto uso de CPU" "O uso de CPU está em ${cpu_usage}%, acima do limite de ${MAX_CPU_THRESHOLD}%."
        return 1
    fi
    
    return 0
}

# Verificar Memória
check_memory() {
    local mem_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    
    if (( $(echo "$mem_usage > $MAX_MEM_THRESHOLD" | bc -l) )); then
        send_alert "Alto uso de Memória" "O uso de memória está em ${mem_usage}%, acima do limite de ${MAX_MEM_THRESHOLD}%."
        return 1
    fi
    
    return 0
}

# Verificar Disco
check_disk() {
    local disk_usage=$(df -h / | grep / | awk '{print $5}' | sed 's/%//')
    
    if [ "$disk_usage" -gt "$MAX_DISK_THRESHOLD" ]; then
        send_alert "Alto uso de Disco" "O uso de disco está em ${disk_usage}%, acima do limite de ${MAX_DISK_THRESHOLD}%."
        return 1
    fi
    
    return 0
}

# Verificar serviços
check_services() {
    local failed_services=()
    
    for service in "${SERVICES[@]}"; do
        systemctl is-active --quiet $service
        if [ $? -ne 0 ]; then
            failed_services+=($service)
        fi
    done
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        local services_str=$(IFS=", "; echo "${failed_services[*]}")
        send_alert "Serviços inativos" "Os seguintes serviços estão inativos: $services_str"
        
        # Tentar reiniciar serviços
        for service in "${failed_services[@]}"; do
            log "Tentando reiniciar o serviço $service..."
            systemctl restart $service
            
            # Verificar se o serviço foi reiniciado com sucesso
            sleep 5
            systemctl is-active --quiet $service
            if [ $? -eq 0 ]; then
                log "Serviço $service reiniciado com sucesso."
            else
                log "Falha ao reiniciar o serviço $service."
            fi
        done
        
        return 1
    fi
    
    return 0
}

# Verificar conectividade VPN
check_vpn() {
    local vpn_status=$(ipsec status | grep ESTABLISHED)
    
    if [ -z "$vpn_status" ]; then
        send_alert "Problema na VPN" "A conexão VPN não está estabelecida."
        
        # Tentar reiniciar a VPN
        log "Tentando reiniciar a VPN..."
        ipsec restart
        
        return 1
    fi
    
    return 0
}

# Verificar replicação do PostgreSQL
check_postgres_replication() {
    local replication_lag=$(sudo -u postgres psql -c "SELECT extract(epoch from (now() - pg_last_xact_replay_timestamp()))::int;" -t)
    
    if [ "$replication_lag" -gt 300 ]; then
        send_alert "Atraso na replicação PostgreSQL" "A replicação do PostgreSQL está atrasada em ${replication_lag} segundos."
        return 1
    fi
    
    return 0
}

# Função principal de monitoramento
monitor() {
    log "Iniciando monitoramento..."
    
    while true; do
        check_cpu
        check_memory
        check_disk
        check_services
        
        # Verificações específicas para servidores específicos
        if systemctl is-active --quiet postgresql; then
            check_postgres_replication
        fi
        
        if systemctl is-active --quiet strongswan; then
            check_vpn
        fi
        
        sleep $CHECK_INTERVAL
    done
}

# Iniciar monitoramento
monitor
