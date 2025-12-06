#!/bin/bash

################################################################################
# Script de Backup de PostgreSQL para AF Construcciones y Servicios
# 
# Este script realiza un backup completo de todas las bases de datos PostgreSQL
# Pausando los servicios dependientes durante el proceso para garantizar
# consistencia de datos.
#
# Bases de datos a respaldar:
#   - n8n_db (n8n - Automatización)
#   - metabase_db (Metabase - BI y Analytics)
#   - nocodb_db (NocoDB - Gestión de datos)
#   - serviciosaf_db (AF - Base de datos de servicios)
#
# Servicios que se pausan durante el backup:
#   - n8n (plataforma de automatización)
#   - metabase (herramienta BI)
#   - nocodb (gestor de datos)
#   - cloudflared (túnel de acceso)
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
TIMESTAMP=$(date +"%Y-%m-%d")

# Variables de PostgreSQL
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

# Bases de datos a respaldar
DATABASES=("n8n_db" "metabase_db" "nocodb_db" "serviciosaf_db")

# Servicios a pausar
SERVICES_TO_PAUSE=("n8n" "metabase" "nocodb" "cloudflared")

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
# Validar requisitos
################################################################################

validate_requirements() {
    info "Validando requisitos del sistema..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker no está instalado"
        exit 1
    fi
    
    if ! command -v pg_dump &> /dev/null; then
        warning "pg_dump no encontrado en el sistema local, usaremos docker exec"
    fi
    
    if [ ! -d "$BACKUP_DIR" ]; then
        info "Creando directorio de backup: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
    
    success "Validación de requisitos completada"
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
        success "Variables de entorno cargadas desde $ENV_FILE"
    else
        warning "Archivo .env no encontrado, usando variables por defecto"
    fi
    
    # Validar variables críticas
    if [ -z "$POSTGRES_PASSWORD" ]; then
        error "POSTGRES_PASSWORD no está configurada"
        exit 1
    fi
}

################################################################################
# Pausar servicios dependientes
################################################################################

pause_services() {
    info "Deteniendo servicios para garantizar consistencia..."
    
    for service in "${SERVICES_TO_PAUSE[@]}"; do
        info "Deteniendo servicio: $service"
        
        if docker compose stop "$service" 2>&1 | grep -q "no container"; then
            warning "Servicio $service no existe"
        else
            success "Servicio $service detenido correctamente"
        fi
    done
    
    info "Esperando 5 segundos para asegurar que los servicios se detuvieron..."
    sleep 5
}

################################################################################
# Reanudar servicios
################################################################################

resume_services() {
    info "Iniciando servicios..."
    
    for service in "${SERVICES_TO_PAUSE[@]}"; do
        info "Iniciando servicio: $service"
        
        if docker compose start "$service" 2>/dev/null; then
            success "Servicio $service iniciado correctamente"
        else
            warning "No se pudo iniciar el servicio $service"
        fi
    done
    
    success "Todos los servicios han sido iniciados"
}

################################################################################
# Crear backups individuales
################################################################################

backup_database() {
    local db_name="$1"
    local backup_file="${BACKUP_DIR}/${db_name}_${TIMESTAMP}.sql"
    
    info "Iniciando backup de base de datos: $db_name"
    
    # Usar docker exec para ejecutar pg_dump dentro del contenedor
    if docker exec "$POSTGRES_CONTAINER" \
        pg_dump -U "$POSTGRES_USER" "$db_name" 2>/dev/null > "$backup_file"; then
        
        local file_size=$(du -h "$backup_file" | cut -f1)
        success "Backup de $db_name completado: $file_size ($backup_file)"
    else
        error "Error al respaldar la base de datos: $db_name"
        return 1
    fi
}

################################################################################
# Crear backup de todas las bases de datos
################################################################################

backup_all_databases() {
    info "Iniciando backup de todas las bases de datos..."
    
    local failed_backups=0
    
    for db in "${DATABASES[@]}"; do
        if ! backup_database "$db"; then
            ((failed_backups++))
        fi
    done
    
    if [ $failed_backups -eq 0 ]; then
        success "Todos los backups se completaron exitosamente"
        return 0
    else
        error "$failed_backups backup(s) fallaron"
        return 1
    fi
}

################################################################################
# Crear backup de volúmenes Docker importantes
################################################################################

backup_volumes() {
    info "Iniciando backup de volúmenes Docker..."
    
    local volumes_to_backup=(
        "n8n_data"
        "nocodb_data"
        "postgres_data"
    )
    
    for volume_path in "${volumes_to_backup[@]}"; do
        if [ -d "$SCRIPT_DIR/$volume_path" ]; then
            local archive_name="${BACKUP_DIR}/volume_${volume_path}_${TIMESTAMP}.tar.gz"
            info "Comprimiendo volumen: $volume_path"
            
            if tar -czf "$archive_name" -C "$SCRIPT_DIR" "$volume_path" 2>/dev/null; then
                local size=$(du -h "$archive_name" | cut -f1)
                success "Volumen comprimido: $size ($archive_name)"
            else
                warning "Error al comprimir volumen: $volume_path"
            fi
        else
            warning "Volumen no encontrado: $volume_path"
        fi
    done
}

################################################################################
# Limpiar backups antiguos
################################################################################

cleanup_old_backups() {
    info "Limpiando backups anteriores (mantener últimos 7 días)..."
    
    local days_to_keep=7
    local count=$(find "$BACKUP_DIR" -name "*_db_*.sql" -type f -mtime -${days_to_keep} | wc -l)
    local deleted=$(find "$BACKUP_DIR" -name "*_db_*.sql" -type f -mtime +${days_to_keep} -delete -print | wc -l)
    
    if [ $deleted -gt 0 ]; then
        success "Se eliminaron $deleted backups anteriores a $days_to_keep días"
    else
        info "No hay backups para eliminar (todos tienen menos de $days_to_keep días)"
    fi
}

################################################################################
# Función principal
################################################################################

main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  BACKUP DE POSTGRESQL - AF CONSTRUCCIONES Y SERVICIOS                      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    info "Iniciando proceso de backup..."
    info "Timestamp: $TIMESTAMP"
    
    # Validar requisitos
    validate_requirements
    
    # Cargar variables de entorno
    load_env_variables
    
    # Pausar servicios
    pause_services
    
    # Crear trap para reanudar servicios en caso de error
    trap 'error "Script interrumpido"; resume_services; exit 1' INT TERM EXIT
    
    # Realizar backups
    if backup_all_databases; then
        success "Backups de bases de datos completados"
        
        # Mostrar resumen
        echo ""
        success "BACKUP COMPLETADO EXITOSAMENTE"
        echo ""
        info "Resumen:"
        info "  - Directorio: $BACKUP_DIR"
        info "  - Archivos: $(find "$BACKUP_DIR" -name "*_${TIMESTAMP}.sql" | wc -l)"
        info "  - Tamaño total: $(du -sh "$BACKUP_DIR" | cut -f1)"
        echo ""
        
    else
        error "BACKUP FALLIDO - Se encontraron errores"
        exit 1
    fi
    
    # Reanudar servicios
    resume_services
    
    # Limpiar backups antiguos
    cleanup_old_backups
    
    # Remover trap
    trap - INT TERM EXIT
    
    info "Proceso de backup finalizado"
}

################################################################################
# Punto de entrada
################################################################################

# Mostrar uso
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    cat << EOF
Uso: $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Ejecutar backup completo (pausa servicios)
  --help, -h        Mostrar esta ayuda
  --clean-logs      Limpiar archivos de log
  --status          Mostrar estado del último backup
  --list            Listar todos los backups disponibles

Ejemplos:
  $0                    # Ejecutar backup completo
  $0 --list             # Listar backups
  $0 --clean-logs       # Limpiar logs antiguos

EOF
    exit 0
fi

# Opciones especiales
case "$1" in
    --clean-logs)
        find "$BACKUP_DIR" -name "backup_*.log" -type f -mtime +30 -delete
        echo "Logs limpiados"
        exit 0
        ;;
    --status)
        if [ -f "$BACKUP_DIR/backup_manifest_$(ls -t "$BACKUP_DIR" | head -1 | grep -oP '\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}').txt" ]; then
            echo "Último backup:"
            ls -lh "$BACKUP_DIR"/postgres_*.sql | head -1
        else
            echo "No se encontraron backups"
        fi
        exit 0
        ;;
    --list)
        echo "Backups disponibles:"
        ls -lhS "$BACKUP_DIR"/postgres_*.sql 2>/dev/null | awk '{print $9, "(" $5 ")"}'
        exit 0
        ;;
esac

# Ejecutar backup principal
main

exit 0
