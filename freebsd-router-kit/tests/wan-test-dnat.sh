#!/bin/sh
set -eu
if [ "$#" -ne 1 ]; then
    echo "Uso: $0 IP_WAN_DO_ROTEADOR" >&2
    exit 2
fi
ROUTER_WAN_IP=$1
printf 'Mensagem de teste DNAT vinda da WAN\n' | nc -v -w 5 "$ROUTER_WAN_IP" 80
