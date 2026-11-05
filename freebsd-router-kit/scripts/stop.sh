#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"
require_freebsd
require_root

warn "Este script interrompe o firewall PF. Use apenas no laboratorio e pela console local."
service kea stop || true
service pf stop || true
service pflog stop || true
log "Servicos interrompidos. O encaminhamento IPv4 persistente nao foi removido."
