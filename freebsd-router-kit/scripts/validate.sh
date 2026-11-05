#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"
require_freebsd
load_config
validate_config

printf '\n=== Interfaces ===\n'
ifconfig "$WAN_IF" || die "Falha ao consultar interface WAN $WAN_IF"
ifconfig "$LAN_IF" || die "Falha ao consultar interface LAN $LAN_IF"

printf '\n=== Encaminhamento IPv4 ===\n'
sysctl net.inet.ip.forwarding

printf '\n=== Rotas IPv4 ===\n'
netstat -rn -f inet

printf '\n=== Validacao PF ===\n'
[ -f /etc/pf.conf ] || die "/etc/pf.conf nao existe."
pfctl -nf /etc/pf.conf
printf 'PF: sintaxe valida.\n'

printf '\n=== Validacao Kea DHCPv4 ===\n'
[ -f /usr/local/etc/kea/kea-dhcp4.conf ] || die "Configuracao Kea nao existe."
kea-dhcp4 -t /usr/local/etc/kea/kea-dhcp4.conf
printf 'Kea: configuracao aceita pelo parser.\n'

printf '\n=== Verificacoes adicionais ===\n'
printf 'Regras PF:\n'
pfctl -sr || true
printf '\nRegras NAT/RDR:\n'
pfctl -sn || true
printf '\nValidacao concluida. Isso verifica configuracao local, nao substitui os testes entre dois equipamentos.\n'
