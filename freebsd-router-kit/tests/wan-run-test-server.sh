#!/bin/sh
set -eu
PORT=${1:-9000}
case "$PORT" in *[!0-9]*|'') echo "Porta invalida" >&2; exit 2;; esac
printf 'Servidor TCP de teste para NAT escutando na porta %s.\n' "$PORT"
printf 'Execute o cliente de teste na maquina LAN. Ctrl+C encerra.\n'
exec nc -l "$PORT"
