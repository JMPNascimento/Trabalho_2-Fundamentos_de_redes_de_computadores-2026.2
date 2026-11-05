#!/bin/sh
set -eu
if [ "$#" -ne 1 ]; then
    echo "Uso: $0 INTERFACE_LAN_DO_CLIENTE" >&2
    exit 2
fi
IFACE=$1
[ "$(id -u)" -eq 0 ] || { echo "Execute como root." >&2; exit 1; }
printf 'Renovando lease DHCP na interface %s...\n' "$IFACE"
dhclient -r "$IFACE" || true
dhclient -v "$IFACE"
printf '\nEndereco recebido:\n'
ifconfig "$IFACE"
