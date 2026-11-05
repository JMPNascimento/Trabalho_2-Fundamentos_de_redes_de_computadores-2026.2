#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"
require_freebsd
require_root
load_config
validate_config

[ -f /etc/pf.conf ] || die "/etc/pf.conf nao existe. Execute ./scripts/configure.sh."
[ -f /usr/local/etc/kea/kea-dhcp4.conf ] || die "Configuracao Kea nao encontrada. Execute ./scripts/configure.sh."

log "Aplicando endereco da LAN..."
ifconfig "$LAN_IF" "inet" "${LAN_ADDRESS}/${LAN_PREFIX}" up

if [ "$WAN_MODE" = "static" ]; then
    log "Aplicando endereco estatico da WAN..."
    ifconfig "$WAN_IF" inet "${WAN_STATIC_ADDRESS}/${WAN_PREFIX}" up
else
    log "WAN em DHCP: verificando se a interface ja recebeu um endereco..."
    if ! ifconfig "$WAN_IF" | grep -Eq 'inet [0-9]'; then
        dhclient "$WAN_IF"
    fi
fi

log "Habilitando encaminhamento IPv4..."
sysctl net.inet.ip.forwarding=1 >/dev/null

log "Validando e carregando PF..."
pfctl -nf /etc/pf.conf
service pflog onestart || true
service pf restart

log "Iniciando/reiniciando Kea DHCPv4..."
service kea restart

log "Servicos iniciados. Consulte ./scripts/status.sh."
