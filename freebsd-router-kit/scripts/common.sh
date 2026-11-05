#!/bin/sh
# Funcoes compartilhadas pelos scripts do projeto.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
CONFIG_FILE="$PROJECT_DIR/config/router.conf"

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[AVISO] %s\n' "$*" >&2; }
die() { printf '[ERRO] %s\n' "$*" >&2; exit 1; }

require_root() {
    [ "$(id -u)" -eq 0 ] || die "Execute este script como root (por exemplo, su - e depois ./scripts/...)."
}

require_freebsd() {
    [ "$(uname -s)" = "FreeBSD" ] || die "Este script deve ser executado no FreeBSD."
}

load_config() {
    [ -f "$CONFIG_FILE" ] || die "Arquivo de configuracao nao encontrado: $CONFIG_FILE"
    # O arquivo e mantido pelo grupo; edite apenas com valores confiaveis.
    . "$CONFIG_FILE"

    : "${WAN_IF:?WAN_IF nao definido}"
    : "${LAN_IF:?LAN_IF nao definido}"
    : "${WAN_MODE:?WAN_MODE nao definido}"
    : "${WAN_STATIC_ADDRESS:?WAN_STATIC_ADDRESS nao definido}"
    : "${WAN_PREFIX:?WAN_PREFIX nao definido}"
    : "${WAN_GATEWAY:?WAN_GATEWAY nao definido}"
    : "${LAN_ADDRESS:?LAN_ADDRESS nao definido}"
    : "${LAN_NETWORK:?LAN_NETWORK nao definido}"
    : "${LAN_PREFIX:?LAN_PREFIX nao definido}"
    : "${DHCP_POOL_START:?DHCP_POOL_START nao definido}"
    : "${DHCP_POOL_END:?DHCP_POOL_END nao definido}"
    : "${DHCP_RESERVED_MAC:?DHCP_RESERVED_MAC nao definido}"
    : "${DHCP_RESERVED_IP:?DHCP_RESERVED_IP nao definido}"
    : "${DHCP_LEASE_TIME:?DHCP_LEASE_TIME nao definido}"
    : "${DNS_SERVER:?DNS_SERVER nao definido}"
    : "${WEB_SERVER_IP:?WEB_SERVER_IP nao definido}"
    : "${WAN_TEST_SERVER_IP:?WAN_TEST_SERVER_IP nao definido}"
    : "${ROUTER_WAN_TEST_IP:?ROUTER_WAN_TEST_IP nao definido}"
}

valid_ipv4() {
    printf '%s\n' "$1" | awk -F. '
        NF != 4 { exit 1 }
        {
            for (i = 1; i <= 4; i++) {
                if ($i !~ /^[0-9]+$/ || $i < 0 || $i > 255) exit 1
            }
        }
    '
}

validate_config() {
    [ "$WAN_IF" != "$LAN_IF" ] || die "WAN_IF e LAN_IF precisam ser interfaces diferentes."
    case "$WAN_MODE" in
        static|dhcp) ;;
        *) die "WAN_MODE deve ser 'static' ou 'dhcp'." ;;
    esac
    [ "$LAN_PREFIX" = "16" ] || die "O enunciado exige uma LAN /16; mantenha LAN_PREFIX=16."
    valid_ipv4 "$LAN_ADDRESS" || die "LAN_ADDRESS invalido: $LAN_ADDRESS"
    valid_ipv4 "$LAN_NETWORK" || die "LAN_NETWORK invalido: $LAN_NETWORK"
    valid_ipv4 "$DHCP_POOL_START" || die "DHCP_POOL_START invalido: $DHCP_POOL_START"
    valid_ipv4 "$DHCP_POOL_END" || die "DHCP_POOL_END invalido: $DHCP_POOL_END"
    valid_ipv4 "$DHCP_RESERVED_IP" || die "DHCP_RESERVED_IP invalido: $DHCP_RESERVED_IP"
    valid_ipv4 "$DNS_SERVER" || die "DNS_SERVER invalido: $DNS_SERVER"
    valid_ipv4 "$WEB_SERVER_IP" || die "WEB_SERVER_IP invalido: $WEB_SERVER_IP"
    valid_ipv4 "$WAN_TEST_SERVER_IP" || die "WAN_TEST_SERVER_IP invalido: $WAN_TEST_SERVER_IP"
    valid_ipv4 "$ROUTER_WAN_TEST_IP" || die "ROUTER_WAN_TEST_IP invalido: $ROUTER_WAN_TEST_IP"
    if [ "$WAN_MODE" = "static" ]; then
        valid_ipv4 "$WAN_STATIC_ADDRESS" || die "WAN_STATIC_ADDRESS invalido: $WAN_STATIC_ADDRESS"
        valid_ipv4 "$WAN_GATEWAY" || die "WAN_GATEWAY invalido: $WAN_GATEWAY"
    fi
    printf '%s\n' "$DHCP_RESERVED_MAC" | grep -Eq '^[[:xdigit:]]{2}(:[[:xdigit:]]{2}){5}$' \
        || die "DHCP_RESERVED_MAC deve estar no formato aa:bb:cc:dd:ee:ff."
    [ "$WEB_SERVER_IP" = "$DHCP_RESERVED_IP" ] \
        || die "Para este kit, WEB_SERVER_IP deve ser igual a DHCP_RESERVED_IP."
    case "$DHCP_LEASE_TIME" in
        ''|*[!0-9]*) die "DHCP_LEASE_TIME deve ser um numero inteiro em segundos." ;;
    esac
}

backup_file() {
    target=$1
    if [ -f "$target" ]; then
        stamp=$(date '+%Y%m%d-%H%M%S')
        cp -p "$target" "$target.backup-$stamp"
        log "Backup criado: $target.backup-$stamp"
    fi
}
