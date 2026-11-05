#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"
require_freebsd
load_config

printf '\n=== FreeBSD ===\n'
uname -a
printf '\n=== WAN (%s) ===\n' "$WAN_IF"
ifconfig "$WAN_IF" || true
printf '\n=== LAN (%s) ===\n' "$LAN_IF"
ifconfig "$LAN_IF" || true
printf '\n=== Roteamento ===\n'
sysctl net.inet.ip.forwarding || true
netstat -rn -f inet || true
printf '\n=== PF: estado, filtros e NAT ===\n'
pfctl -s info || true
pfctl -sr || true
pfctl -sn || true
printf '\n=== Kea ===\n'
service kea status || true
