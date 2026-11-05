#!/bin/sh
set -eu
if [ "$#" -ne 1 ]; then
    echo "Uso: $0 IP_EXTERNO_OU_HOST_WAN" >&2
    exit 2
fi
TARGET=$1
printf 'Tentando ping para %s. A regra do trabalho deve bloquear ICMP Echo Request encaminhado.\n' "$TARGET"
if ping -c 3 "$TARGET"; then
    echo "FALHA: houve resposta ao ping. Verifique a regra ICMP no PF." >&2
    exit 1
else
    echo "O ping nao recebeu resposta. Isso e compativel com o bloqueio, mas confirme no roteador com: pfctl -vvsr e tcpdump -n -i pflog0 icmp"
fi
