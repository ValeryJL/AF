#!/usr/bin/env bash
set -euo pipefail

############################
# CONFIG
############################
PROJECT_NAME="AF Construcciones"
BACKUP_DIR="$HOME/AF/backup"
POSTGRES_CONTAINER="postgres"
POSTGRES_USER="admin"

DBS=(
  n8n_db
  metabase_db
  nocodb_db
  serviciosaf_db
)

SERVICES=(
  n8n
  metabase
  nocodb
  cloudflared
)

############################
# FLAGS
############################
RESTORE_ALL=false
NO_CONFIRM=false
DRY_RUN=false

############################
# COLORS
############################
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

############################
# LOGGING
############################
ts() { date '+%Y-%m-%d %H:%M:%S'; }

log()      { echo -e "[$(ts)] [LOG]      $1"; }
info()     { echo -e "${BLUE}[$(ts)] [INFO]     $1${NC}"; }
warn()     { echo -e "${YELLOW}[$(ts)] [WARN]     $1${NC}"; }
error()    { echo -e "${RED}[$(ts)] [ERROR]    $1${NC}"; }
success()  { echo -e "${GREEN}[$(ts)] [SUCCESS]  $1${NC}"; }

run() {
  log "RUN: $*"
  if $DRY_RUN; then
    log "DRY-RUN: comando no ejecutado"
    return 0
  fi

  eval "$@"
  RC=$?
  log "EXIT CODE: $RC"
  return $RC
}

section() {
  echo
  echo "========================================"
  echo "$1"
  echo "========================================"
  echo
}

############################
# ARGUMENTOS
############################
log "Argumentos recibidos: $*"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) RESTORE_ALL=true ;;
    --no-confirm) NO_CONFIRM=true ;;
    --dry-run) DRY_RUN=true ;;
    *)
      error "Argumento desconocido: $1"
      exit 1
      ;;
  esac
  shift
done

############################
# HEADER
############################
section "RESTORE DEBUG – $PROJECT_NAME"

############################
# VALIDACIONES
############################
info "Verificando BACKUP_DIR: $BACKUP_DIR"
if [ ! -d "$BACKUP_DIR" ]; then
  error "El directorio de backups NO existe"
  exit 1
else
  ls -lh "$BACKUP_DIR"
fi

info "Verificando contenedor PostgreSQL"
if ! docker ps -a --format '{{.Names}}' | grep -qx "$POSTGRES_CONTAINER"; then
  error "Contenedor PostgreSQL '$POSTGRES_CONTAINER' no encontrado"
  exit 1
fi

############################
# DETECTAR SERVICIOS ACTIVOS
############################
ACTIVE_SERVICES=()
info "Detectando servicios activos..."

for svc in "${SERVICES[@]}"; do
  if docker ps --format '{{.Names}}' | grep -qx "$svc"; then
    info "Servicio activo detectado: $svc"
    ACTIVE_SERVICES+=("$svc")
  else
    log "Servicio NO activo: $svc"
  fi
done

info "Servicios activos finales: ${ACTIVE_SERVICES[*]:-NINGUNO}"

############################
# CONFIRMACION
############################
if ! $NO_CONFIRM && ! $DRY_RUN; then
  warn "ESTO VA A BORRAR BASES DE DATOS"
  read -rp "Escribí YES para continuar: " CONFIRM
  [[ "$CONFIRM" == "YES" ]] || exit 1
fi

############################
# FUNCIONES DE SERVICIOS
############################
stop_services() {
  info "Deteniendo servicios..."
  for svc in "${ACTIVE_SERVICES[@]}"; do
    run "docker stop $svc"
  done
}

start_services() {
  info "Iniciando servicios..."
  for svc in "${ACTIVE_SERVICES[@]}"; do
    run "docker start $svc"
  done
}

############################
# FUNCION RESTORE DB
############################
restore_db() {
  local DB="$1"
  section "RESTORE DB: $DB"

  local FILE
  FILE=$(ls -t "$BACKUP_DIR"/${DB}_*.sql 2>/dev/null | head -1 || true)

  if [ -z "$FILE" ]; then
    warn "NO HAY BACKUP PARA $DB"
    return 0
  fi

  info "Usando backup: $FILE"

  run "docker exec $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d postgres -c \"DROP DATABASE IF EXISTS $DB WITH (FORCE);\""
  run "docker exec $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d postgres -c \"CREATE DATABASE $DB;\""
  run "docker exec -i $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $DB < \"$FILE\""

  success "Restore finalizado para $DB"
}

############################
# EJECUCION
############################
stop_services

if $RESTORE_ALL; then
  for db in "${DBS[@]}"; do
    restore_db "$db"
  done
else
  warn "--all no especificado, no se restauran bases"
fi

start_services

success "RESTORE DEBUG FINALIZADO"
