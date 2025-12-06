#!/bin/bash

################################################################################
# Script de Restauración de PostgreSQL para AF Construcciones y Servicios
# 
# Este script restaura una base de datos específica desde un archivo de backup
# Elimina completamente la base de datos existente y la recrea desde el backup
#
# Uso: ./restore.sh <nombre_db> [fecha]
# Ejemplo: ./restore.sh n8n_db 2025-12-06
################################################################################

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="${PARENT_DIR}/backup"
ENV_FILE="${PARENT_DIR}/.env"
POSTGRES_CONTAINER="postgres"

# Variables de PostgreSQL
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

# Bases de datos válidas
VALID_DATABASES=("n8n_db" "metabase_db" "nocodb_db" "serviciosaf_db")

# Servicios relacionados con cada base de datos
declare -A DB_SERVICES
DB_SERVICES["n8n_db"]="n8n"
DB_SERVICES["metabase_db"]="metabase"
DB_SERVICES["nocodb_db"]="nocodb"
DB_SERVICES["serviciosaf_db"]=""

################################################################################
# Funciones auxiliares
################################################################################

info() {
    echo -e "${BLUE}[INFO]${NC} $@"
}

success() {
    echo -e "${GREEN}[✓]${NC} $@"
}

warning() {
    echo -e "${YELLOW}[⚠]${NC} $@"
}

error() {
    echo -e "${RED}[✗]${NC} $@"
}

################################################################################
# Validar argumentos
################################################################################

validate_arguments() {
    if [ -z "$1" ]; then
        error "Debe especificar el nombre de la base de datos"
        echo ""
        echo "Uso: $0 <nombre_db> [fecha]"
        echo ""
        echo "Bases de datos disponibles:"
        printf '  - %s\n' "${VALID_DATABASES[@]}"
        echo ""
        echo "Ejemplos:"
        echo "  $0 n8n_db                    # Busca el backup más reciente"
        echo "  $0 metabase_db 2025-12-06    # Usa backup de fecha específica"
        exit 1
    fi
    
    DB_NAME="$1"
    
    # Validar que la base de datos sea válida
    local valid=false
    for db in "${VALID_DATABASES[@]}"; do
        if [ "$db" = "$DB_NAME" ]; then
            valid=true
            break
        fi
    done
    
    if [ "$valid" = false ]; then
        error "Base de datos no válida: $DB_NAME"
        echo ""
        echo "Bases de datos disponibles:"
        printf '  - %s\n' "${VALID_DATABASES[@]}"
        exit 1
    fi
    
    # Obtener fecha del backup
    if [ -z "$2" ]; then
        # Buscar el backup más reciente
        BACKUP_DATE=$(ls -t "$BACKUP_DIR"/${DB_NAME}_*.sql 2>/dev/null | head -1 | grep -oP '\d{4}-\d{2}-\d{2}')
        if [ -z "$BACKUP_DATE" ]; then
            error "No se encontraron backups para $DB_NAME"
            exit 1
        fi
        info "Usando backup más reciente: $BACKUP_DATE"
    else
        BACKUP_DATE="$2"
    fi
    
    BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${BACKUP_DATE}.sql"
    
    if [ ! -f "$BACKUP_FILE" ]; then
        error "Archivo de backup no encontrado: $BACKUP_FILE"
        echo ""
        echo "Backups disponibles para $DB_NAME:"
        ls -lh "$BACKUP_DIR"/${DB_NAME}_*.sql 2>/dev/null || echo "  (ninguno)"
        exit 1
    fi
    
    success "Archivo de backup encontrado: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
}

################################################################################
# Cargar variables de entorno
################################################################################

load_env_variables() {
    info "Cargando variables de entorno..."
    
    if [ -f "$ENV_FILE" ]; then
        set -a
        source "$ENV_FILE"
        set +a
        success "Variables de entorno cargadas"
    else
        warning "Archivo .env no encontrado, usando variables por defecto"
    fi
    
    if [ -z "$POSTGRES_PASSWORD" ]; then
        error "POSTGRES_PASSWORD no está configurada"
        exit 1
    fi
}

################################################################################
# Detener servicios relacionados
################################################################################

stop_related_services() {
    local service="${DB_SERVICES[$DB_NAME]}"
    
    if [ -n "$service" ]; then
        info "Deteniendo servicio relacionado: $service"
        
        if docker compose stop "$service" 2>&1 | grep -q "no container"; then
            warning "Servicio $service no existe"
        else
            success "Servicio $service detenido"
        fi
        
        # También detener cloudflared
        info "Deteniendo servicio: cloudflared"
        docker compose stop cloudflared 2>/dev/null || true
    else
        info "No hay servicios específicos que detener para $DB_NAME"
    fi
    
    sleep 2
}

################################################################################
# Iniciar servicios relacionados
################################################################################

start_related_services() {
    local service="${DB_SERVICES[$DB_NAME]}"
    
    if [ -n "$service" ]; then
        info "Iniciando servicio relacionado: $service"
        
        if docker compose start "$service" 2>/dev/null; then
            success "Servicio $service iniciado"
        else
            warning "No se pudo iniciar el servicio $service"
        fi
        
        # Iniciar cloudflared
        info "Iniciando servicio: cloudflared"
        docker compose start cloudflared 2>/dev/null || true
    fi
}

################################################################################
# Eliminar y recrear base de datos
################################################################################

drop_and_create_database() {
    info "Eliminando base de datos: $DB_NAME"
    
    # Terminar todas las conexiones activas
    docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d postgres -c \
        "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();" \
        2>/dev/null || true
    
    # Esperar un momento para que se cierren las conexiones
    sleep 1
    
    # Eliminar la base de datos con force
    if docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME WITH (FORCE);" 2>/dev/null; then
        success "Base de datos $DB_NAME eliminada"
    else
        error "Error al eliminar la base de datos $DB_NAME"
        return 1
    fi
    
    # Recrear la base de datos
    info "Creando base de datos: $DB_NAME"
    if docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE $DB_NAME;" 2>/dev/null; then
        success "Base de datos $DB_NAME creada"
    else
        error "Error al crear la base de datos $DB_NAME"
        return 1
    fi
}

################################################################################
# Restaurar backup
################################################################################

restore_backup() {
    info "Restaurando backup desde: $BACKUP_FILE"
    
    # Restaurar usando psql
    if cat "$BACKUP_FILE" | docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$DB_NAME" 2>/dev/null; then
        success "Backup restaurado exitosamente"
    else
        error "Error al restaurar el backup"
        return 1
    fi
}

################################################################################
# Verificar restauración
################################################################################

verify_restore() {
    info "Verificando restauración..."
    
    # Contar tablas
    local table_count=$(docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$DB_NAME" -t -c \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | xargs)
    
    if [ -n "$table_count" ] && [ "$table_count" -gt 0 ]; then
        success "Restauración verificada: $table_count tablas encontradas"
    else
        warning "No se pudieron contar las tablas (esto podría ser normal si la base de datos usa otros esquemas)"
    fi
}

################################################################################
# Confirmar acción
################################################################################

confirm_restore() {
    echo ""
    warning "¡ADVERTENCIA!"
    echo ""
    echo "Esta acción eliminará COMPLETAMENTE la base de datos: ${RED}$DB_NAME${NC}"
    echo "Y la reemplazará con el backup del: ${YELLOW}$BACKUP_DATE${NC}"
    echo ""
    echo "Archivo de backup: $BACKUP_FILE"
    echo "Tamaño: $(du -h "$BACKUP_FILE" | cut -f1)"
    echo ""
    
    if [ -n "${DB_SERVICES[$DB_NAME]}" ]; then
        echo "Servicio que será detenido: ${DB_SERVICES[$DB_NAME]}"
        echo ""
    fi
    
    read -p "¿Está seguro de continuar? (escriba 'SI' en mayúsculas): " response
    
    if [ "$response" != "SI" ]; then
        error "Operación cancelada por el usuario"
        exit 0
    fi
}

################################################################################
# Función principal
################################################################################

main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  RESTAURACIÓN DE POSTGRESQL - AF CONSTRUCCIONES Y SERVICIOS                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Validar argumentos
    validate_arguments "$@"
    
    # Cargar variables de entorno
    load_env_variables
    
    # Confirmar acción
    confirm_restore
    
    echo ""
    info "Iniciando proceso de restauración..."
    
    # Detener servicios
    stop_related_services
    
    # Crear trap para reiniciar servicios en caso de error
    trap 'error "Script interrumpido"; start_related_services; exit 1' INT TERM EXIT
    
    # Eliminar y recrear base de datos
    if ! drop_and_create_database; then
        error "Error al preparar la base de datos"
        start_related_services
        exit 1
    fi
    
    # Restaurar backup
    if ! restore_backup; then
        error "Error al restaurar el backup"
        start_related_services
        exit 1
    fi
    
    # Verificar restauración
    verify_restore
    
    # Iniciar servicios
    start_related_services
    
    # Remover trap
    trap - INT TERM EXIT
    
    echo ""
    success "RESTAURACIÓN COMPLETADA EXITOSAMENTE"
    echo ""
    info "Base de datos: $DB_NAME"
    info "Backup usado: $BACKUP_DATE"
    info "Archivo: $BACKUP_FILE"
    echo ""
}

################################################################################
# Punto de entrada
################################################################################

# Mostrar ayuda
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    cat << EOF
Script de Restauración de Base de Datos PostgreSQL

Uso: $0 <nombre_db> [fecha]

Parámetros:
  nombre_db    Nombre de la base de datos a restaurar (requerido)
  fecha        Fecha del backup en formato YYYY-MM-DD (opcional)
               Si no se especifica, usa el backup más reciente

Bases de datos disponibles:
$(printf '  - %s\n' "${VALID_DATABASES[@]}")

Ejemplos:
  $0 n8n_db                    # Restaura n8n_db con el backup más reciente
  $0 metabase_db 2025-12-06    # Restaura metabase_db con backup del 6 de diciembre
  $0 --list n8n_db             # Lista todos los backups de n8n_db

Opciones:
  --help, -h        Mostrar esta ayuda
  --list <db>       Listar backups disponibles para una base de datos

ADVERTENCIA: Esta operación elimina COMPLETAMENTE la base de datos existente.

EOF
    exit 0
fi

# Listar backups
if [ "$1" == "--list" ]; then
    if [ -z "$2" ]; then
        echo "Backups disponibles:"
        for db in "${VALID_DATABASES[@]}"; do
            echo ""
            echo "$db:"
            ls -lh "$BACKUP_DIR"/${db}_*.sql 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || echo "  (ninguno)"
        done
    else
        echo "Backups disponibles para $2:"
        ls -lh "$BACKUP_DIR"/${2}_*.sql 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || echo "  (ninguno)"
    fi
    exit 0
fi

# Ejecutar restauración
main "$@"

exit 0
