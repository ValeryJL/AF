#!/usr/bin/env bash
set -euo pipefail

############################
# CONFIG
############################
PROJECT_NAME="AF Construcciones"
BACKUP_DIR="$HOME/AF/backup"
POSTGRES_CONTAINER="postgres"
POSTGRES_USER="admin"

# Lista completa de bases de datos
DBS=(
  n8n_db
  metabase_db
  nocodb_db
  serviciosaf_db
)

# Servicios que dependen de la DB
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
SELECTED_DB=""
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
}

section() {
  echo -e "\n${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}\n"
}

############################
# ARGUMENTOS
############################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) RESTORE_ALL=true ;;
    --db) shift; SELECTED_DB="$1" ;;
    --no-confirm) NO_CONFIRM=true ;;
    --dry-run) DRY_RUN=true ;;
    *) error "Argumento desconocido: $1"; exit 1 ;;
  esac
  shift
done

############################
# VALIDACIONES
############################
section "RESTORE SYSTEM – $PROJECT_NAME"

if [ ! -d "$BACKUP_DIR" ]; then
  error "El directorio de backups NO existe en $BACKUP_DIR"
  exit 1
fi

if ! docker ps -a --format '{{.Names}}' | grep -qx "$POSTGRES_CONTAINER"; then
  error "Contenedor PostgreSQL '$POSTGRES_CONTAINER' no encontrado."
  exit 1
fi

# Validar que si se eligió una DB, esta sea parte de la lista permitida
if [[ -n "$SELECTED_DB" ]]; then
    FOUND=false
    for db in "${DBS[@]}"; do
        [[ "$db" == "$SELECTED_DB" ]] && FOUND=true
    done
    if [ "$FOUND" = false ]; then
        error "La base de datos '$SELECTED_DB' no está en la lista de configuración (DBS)."
        exit 1
    fi
fi

############################
# DETECTAR SERVICIOS ACTIVOS
############################
ACTIVE_SERVICES=()
info "Detectando servicios activos para detener..."
for svc in "${SERVICES[@]}"; do
  if docker ps --format '{{.Names}}' | grep -qx "$svc"; then
    ACTIVE_SERVICES+=("$svc")
  fi
done

############################
# FUNCIONES DE EJECUCIÓN
############################
stop_services() {
  [[ ${#ACTIVE_SERVICES[@]} -eq 0 ]] && return
  info "Deteniendo servicios: ${ACTIVE_SERVICES[*]}"
  for svc in "${ACTIVE_SERVICES[@]}"; do
    run "docker stop $svc"
  done
}

start_services() {
  [[ ${#ACTIVE_SERVICES[@]} -eq 0 ]] && return
  info "Reiniciando servicios..."
  for svc in "${ACTIVE_SERVICES[@]}"; do
    run "docker start $svc"
  done
}

restore_db() {
  local DB="$1"
  echo -e "\n--- Restaurando: $DB ---"
  local FILE
  FILE=$(ls -t "$BACKUP_DIR"/${DB}_*.sql 2>/dev/null | head -1 || true)

  if [ -z "$FILE" ]; then
    warn "No se encontró ningún archivo de backup para $DB en $BACKUP_DIR"
    return 0
  fi

  info "Archivo detectado: $(basename "$FILE")"
  
  run "docker exec $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d postgres -c \"DROP DATABASE IF EXISTS $DB WITH (FORCE);\""
  run "docker exec $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d postgres -c \"CREATE DATABASE $DB;\""
  run "docker exec -i $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $DB < \"$FILE\""
  
  success "Base de datos $DB restaurada."
}

############################
# MAIN
############################
if ! $RESTORE_ALL && [[ -z "$SELECTED_DB" ]]; then
  error "Debes especificar --all o --db <nombre_db>"
  exit 1
fi

# Confirmación
if ! $NO_CONFIRM; then
  warn "ESTO REEMPLAZARÁ LOS DATOS ACTUALES"
  read -rp "Escribí YES para proceder con el restore: " CONFIRM
  [[ "$CONFIRM" == "YES" ]] || { error "Operación cancelada"; exit 1; }
fi

stop_services

if $RESTORE_ALL; then
  for db in "${DBS[@]}"; do restore_db "$db"; done
else
  restore_db "$SELECTED_DB"
fi

start_services

success "PROCESO FINALIZADO EXITOSAMENTE"
