#!/bin/sh
set -eu
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Uso: $0 IP_SERVIDOR_NA_WAN [PORTA]" >&2
    exit 2
fi
WAN_HOST=$1
PORT=${2:-9000}
printf 'Mensagem de teste NAT enviada da LAN\n' | nc -v -w 5 "$WAN_HOST" "$PORT"
printf 'Conexao TCP realizada. Na maquina WAN, confira se a origem observada e o IP WAN do roteador.\n'
