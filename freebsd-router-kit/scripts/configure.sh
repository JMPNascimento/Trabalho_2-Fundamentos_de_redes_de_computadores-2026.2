#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"
require_freebsd
require_root
load_config
validate_config

command -v sysrc >/dev/null 2>&1 || die "sysrc nao encontrado."
command -v pfctl >/dev/null 2>&1 || die "pfctl nao encontrado."
command -v kea-dhcp4 >/dev/null 2>&1 || die "Kea nao instalado. Execute ./scripts/install.sh primeiro."

if ! ifconfig "$WAN_IF" >/dev/null 2>&1; then
    die "Interface WAN '$WAN_IF' nao existe. Confira os nomes com ifconfig e edite config/router.conf."
fi
if ! ifconfig "$LAN_IF" >/dev/null 2>&1; then
    die "Interface LAN '$LAN_IF' nao existe. Confira os nomes com ifconfig e edite config/router.conf."
fi

RC_LOCAL="/etc/rc.conf.local"
PF_TMP=$(mktemp /tmp/pf.conf.XXXXXX)
KEA_TMP=$(mktemp /tmp/kea-dhcp4.conf.XXXXXX)
trap 'rm -f "$PF_TMP" "$KEA_TMP"' EXIT HUP INT TERM

log "Gerando regras PF..."
cat > "$PF_TMP" <<EOF_PF
# Gerado pelo projeto FreeBSD Router Lab.
# NAT e RDR sao processados antes das regras de filtragem.
wan_if = "${WAN_IF}"
lan_if = "${LAN_IF}"
lan_net = "${LAN_NETWORK}/${LAN_PREFIX}"
web_server = "${WEB_SERVER_IP}"

set block-policy drop
set skip on lo0

# NAT: clientes da LAN saem usando o endereco da interface WAN.
nat on \$wan_if inet from \$lan_net to any -> (\$wan_if)

# DNAT: WAN TCP/80 -> servidor LAN TCP/8080.
rdr on \$wan_if inet proto tcp from any to (\$wan_if) port 80 -> \$web_server port 8080

# Politica padrao: bloquear trafego nao explicitamente permitido.
block all

# DHCP: permitir descoberta/solicitacao dos clientes e respostas do servidor.
pass in quick on \$lan_if inet proto udp from any port 68 to any port 67 keep state
pass out quick on \$lan_if inet proto udp from any port 67 to any port 68 keep state

# Requisito do trabalho: bloquear ICMP Echo Request (ping) encaminhado
# da LAN para destinos fora da propria LAN.
block in log quick on \$lan_if inet proto icmp from \$lan_net to ! \$lan_net icmp-type echoreq

# Clientes LAN podem iniciar conexoes para fora (exceto o ping bloqueado acima).
pass in on \$lan_if inet from \$lan_net to any keep state

# Permitir somente o servico publicado pelo DNAT na WAN.
# O PF filtra o destino ja traduzido: servidor LAN, TCP/8080.
pass in on \$wan_if inet proto tcp from any to \$web_server port 8080 keep state

# Permitir saida e trafego de retorno associado a estados existentes.
pass out all keep state
EOF_PF

log "Validando sintaxe PF..."
pfctl -nf "$PF_TMP"

log "Gerando configuracao Kea DHCPv4..."
cat > "$KEA_TMP" <<EOF_KEA
{
  "Dhcp4": {
    "interfaces-config": {
      "interfaces": [ "${LAN_IF}" ]
    },
    "lease-database": {
      "type": "memfile",
      "persist": true,
      "name": "/var/db/kea/dhcp4.leases"
    },
    "valid-lifetime": ${DHCP_LEASE_TIME},
    "renew-timer": 10800,
    "rebind-timer": 21600,
    "authoritative": true,
    "subnet4": [
      {
        "id": 1,
        "subnet": "${LAN_NETWORK}/${LAN_PREFIX}",
        "pools": [
          { "pool": "${DHCP_POOL_START} - ${DHCP_POOL_END}" }
        ],
        "option-data": [
          { "name": "routers", "data": "${LAN_ADDRESS}" },
          { "name": "domain-name-servers", "data": "${DNS_SERVER}" }
        ],
        "reservations": [
          {
            "hw-address": "${DHCP_RESERVED_MAC}",
            "ip-address": "${DHCP_RESERVED_IP}",
            "hostname": "lan-web-server"
          }
        ]
      }
    ],
    "loggers": [
      {
        "name": "kea-dhcp4",
        "output_options": [
          { "output": "/var/log/kea/kea-dhcp4.log" }
        ],
        "severity": "INFO",
        "debuglevel": 0
      }
    ]
  }
}
EOF_KEA

log "Validando sintaxe Kea DHCPv4..."
kea-dhcp4 -t "$KEA_TMP"

log "Salvando arquivos de configuracao..."
backup_file /etc/pf.conf
backup_file /usr/local/etc/kea/kea-dhcp4.conf
install -o root -g wheel -m 0644 "$PF_TMP" /etc/pf.conf
install -o root -g wheel -m 0644 "$KEA_TMP" /usr/local/etc/kea/kea-dhcp4.conf

log "Gravando configuracoes persistentes em $RC_LOCAL..."
if [ "$WAN_MODE" = "dhcp" ]; then
    sysrc -f "$RC_LOCAL" "ifconfig_${WAN_IF}=DHCP"
    sysrc -f "$RC_LOCAL" -x defaultrouter >/dev/null 2>&1 || true
else
    sysrc -f "$RC_LOCAL" "ifconfig_${WAN_IF}=inet ${WAN_STATIC_ADDRESS}/${WAN_PREFIX}"
    sysrc -f "$RC_LOCAL" "defaultrouter=${WAN_GATEWAY}"
fi
sysrc -f "$RC_LOCAL" "ifconfig_${LAN_IF}=inet ${LAN_ADDRESS}/${LAN_PREFIX}"
sysrc -f "$RC_LOCAL" gateway_enable="YES"
sysrc -f "$RC_LOCAL" pf_enable="YES"
sysrc -f "$RC_LOCAL" pf_rules="/etc/pf.conf"
sysrc -f "$RC_LOCAL" pflog_enable="YES"
sysrc -f "$RC_LOCAL" kea_enable="YES"
sysrc -f "$RC_LOCAL" kea_dhcp4_enable="YES"

log "Configuracao gravada. As interfaces nao foram reiniciadas automaticamente."
log "Reinicie a maquina pela console ou aplique a configuracao de interfaces manualmente."
log "Depois execute: ./scripts/start.sh"
