#!/bin/sh
set -eu
PORT=${1:-8080}
case "$PORT" in *[!0-9]*|'') echo "Porta invalida" >&2; exit 2;; esac
printf 'Servidor TCP de teste para DNAT escutando na porta %s.\n' "$PORT"
printf 'Execute o cliente de teste na maquina WAN. Ctrl+C encerra.\n'
exec nc -l "$PORT"
