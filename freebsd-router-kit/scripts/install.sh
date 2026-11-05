#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"
require_freebsd
require_root
load_config
validate_config

command -v pkg >/dev/null 2>&1 || die "pkg nao encontrado. Execute o bootstrap do pkg e tente novamente."

log "Atualizando catalogo de pacotes..."
pkg update -f

log "Instalando Kea DHCP..."
pkg install -y kea

command -v kea-dhcp4 >/dev/null 2>&1 || die "O pacote foi instalado, mas kea-dhcp4 nao foi encontrado."
[ -x /usr/local/etc/rc.d/kea ] || die "Script rc.d do Kea nao encontrado em /usr/local/etc/rc.d/kea."

log "Kea instalado. Versao detectada:"
kea-dhcp4 -v || true
log "Instalacao concluida. Proximo passo: ./scripts/configure.sh"
