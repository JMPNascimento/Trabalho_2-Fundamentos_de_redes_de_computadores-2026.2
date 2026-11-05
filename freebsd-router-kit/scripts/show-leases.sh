#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"
require_freebsd
require_root

LEASE_FILE="/var/db/kea/dhcp4.leases"
LOG_FILE="/var/log/kea/kea-dhcp4.log"

printf '\n=== Banco de leases Kea ===\n'
if [ -f "$LEASE_FILE" ]; then
    cat "$LEASE_FILE"
else
    warn "Arquivo ainda nao criado: $LEASE_FILE"
fi

printf '\n=== Eventos DHCP registrados ===\n'
if [ -f "$LOG_FILE" ]; then
    grep -E 'DHCP4_|lease|LEASE|ACK|OFFER' "$LOG_FILE" | tail -n 100 || true
    printf '\nPara acompanhar em tempo real: tail -f %s\n' "$LOG_FILE"
else
    warn "Log ainda nao criado: $LOG_FILE"
    warn "Confirme se o servico Kea iniciou e se a configuracao de logging foi aplicada."
fi
