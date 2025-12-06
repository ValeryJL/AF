#!/bin/bash

################################################################################
# Script de Instalación - AF Construcciones y Servicios
# 
# Este script configura y levanta completamente el stack de Docker
# Incluye validaciones, creación de directorios, y inicio de servicios
################################################################################

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables de configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
REQUIRED_DIRS=("backup" "postgres/data" "postgres/init" "n8n_data" "nocodb_data" "docs" "scripts")

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

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${YELLOW}▶ $1${NC}"
}

################################################################################
# Validaciones previas
################################################################################

check_prerequisites() {
    print_step "Validando requisitos previos..."
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        error "Docker no está instalado"
        echo "Descarga Docker desde: https://docs.docker.com/get-docker/"
        exit 1
    fi
    success "Docker instalado"
    
    # Verificar Docker Compose
    if ! docker compose version &> /dev/null; then
        error "Docker Compose no está disponible"
        exit 1
    fi
    success "Docker Compose disponible"
    
    # Verificar archivo .env
    if [ ! -f "$ENV_FILE" ]; then
        error "Archivo .env no encontrado"
        echo ""
        echo "El archivo .env es requerido. Por favor, crea uno con:"
        echo "  POSTGRES_USER=admin"
        echo "  POSTGRES_PASSWORD=<contraseña_segura>"
        echo "  POSTGRES_DB=postgres"
        echo "  POSTGRES_PORT=5432"
        exit 1
    fi
    success "Archivo .env encontrado"
    
    # Verificar docker-compose.yml
    if [ ! -f "${SCRIPT_DIR}/docker-compose.yml" ]; then
        error "Archivo docker-compose.yml no encontrado"
        exit 1
    fi
    success "Archivo docker-compose.yml encontrado"
}

################################################################################
# Crear estructura de directorios
################################################################################

create_directories() {
    print_step "Creando estructura de directorios..."
    
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "${SCRIPT_DIR}/${dir}" ]; then
            mkdir -p "${SCRIPT_DIR}/${dir}"
            success "Directorio creado: $dir"
        else
            info "Directorio ya existe: $dir"
        fi
    done
}

################################################################################
# Migrar datos antiguos (si existen)
################################################################################

migrate_legacy_data() {
    print_step "Verificando datos heredados..."
    
    # Migrar postgres-init
    if [ -d "${SCRIPT_DIR}/postgres-init" ] && [ ! -f "${SCRIPT_DIR}/postgres/init/init-db.sh" ]; then
        info "Migrando scripts de inicialización..."
        sudo cp "${SCRIPT_DIR}/postgres-init/init-db.sh" "${SCRIPT_DIR}/postgres/init/" 2>/dev/null || warning "No se pudieron migrar scripts de inicialización"
    fi
    
    # Advertir sobre postgres_data
    if [ -d "${SCRIPT_DIR}/postgres_data" ]; then
        warning "Detectada carpeta postgres_data (deprecada)"
        echo "Puedes eliminarla después de verificar que todo funciona:"
        echo "  rm -rf ${SCRIPT_DIR}/postgres_data"
    fi
    
    # Advertir sobre postgres-init
    if [ -d "${SCRIPT_DIR}/postgres-init" ]; then
        warning "Detectada carpeta postgres-init (deprecada)"
        echo "Puedes eliminarla después de verificar que todo funciona:"
        echo "  rm -rf ${SCRIPT_DIR}/postgres-init"
    fi
}

################################################################################
# Validar configuración de Docker
################################################################################

validate_docker_setup() {
    print_step "Validando configuración de Docker..."
    
    # Verificar imagen postgres
    if ! docker image inspect postgres:15 &>/dev/null; then
        info "Descargando imagen PostgreSQL 15..."
        docker pull postgres:15
    fi
    success "PostgreSQL 15 disponible"
    
    # Verificar imagen metabase
    if ! docker image inspect metabase/metabase &>/dev/null; then
        info "Descargando imagen Metabase..."
        docker pull metabase/metabase
    fi
    success "Metabase disponible"
    
    # Verificar imagen n8n
    if ! docker image inspect n8nio/n8n &>/dev/null; then
        info "Descargando imagen n8n..."
        docker pull n8nio/n8n
    fi
    success "n8n disponible"
    
    # Verificar imagen nocodb
    if ! docker image inspect nocodb/nocodb &>/dev/null; then
        info "Descargando imagen NocoDB..."
        docker pull nocodb/nocodb
    fi
    success "NocoDB disponible"
    
    # Verificar imagen cloudflared
    if ! docker image inspect cloudflare/cloudflared &>/dev/null; then
        info "Descargando imagen Cloudflared..."
        docker pull cloudflare/cloudflared:latest
    fi
    success "Cloudflared disponible"
}

################################################################################
# Cargar variables de entorno
################################################################################

load_environment() {
    print_step "Cargando variables de entorno..."
    
    # Si el archivo .env no existe, crear uno
    if [ ! -f "$ENV_FILE" ]; then
        info "Archivo .env no encontrado, creando uno..."
        
        # Generar contraseña segura
        local postgres_password=$(openssl rand -base64 32)
        
        # Crear .env con valores por defecto
        cat > "$ENV_FILE" << EOF
# Configuración de PostgreSQL
POSTGRES_USER=admin
POSTGRES_PASSWORD=$postgres_password
POSTGRES_DB=postgres
POSTGRES_PORT=5432

# Nombres de bases de datos
N8N_DB_NAME=n8n_db
METABASE_DB_NAME=metabase_db
NOCODB_DB_NAME=nocodb_db
SERVICIOSAF_DB_NAME=serviciosaf_db

# Configuración de n8n
NODE_ENV=production
TIMEZONE=America/Argentina/Buenos_Aires
N8N_HOST=n8n.example.com
N8N_PORT=5678
N8N_PROTOCOL=https
N8N_WEBHOOK_URL=https://n8n.example.com/

# Token de Cloudflared
CLOUDFLARED_TOKEN=
EOF
        
        success ".env creado con contraseña segura"
        warning "⚠️  IMPORTANTE: Edita el .env con tus datos:"
        echo "  - N8N_HOST: cambiar a tu dominio"
        echo "  - CLOUDFLARED_TOKEN: agregar tu token de Cloudflare"
        echo ""
        info "Luego ejecuta: ./install.sh"
        exit 0
    fi
    
    set -a
    source "$ENV_FILE"
    set +a
    
    # Validar variables críticas
    if [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_PASSWORD" ]; then
        error "Variables POSTGRES_USER o POSTGRES_PASSWORD no configuradas en .env"
        exit 1
    fi
    
    success "Variables de entorno cargadas"
}

################################################################################
# Mostrar configuración
################################################################################

show_configuration() {
    print_step "Configuración actual:"
    
    echo ""
    echo "PostgreSQL:"
    echo "  Usuario: $POSTGRES_USER"
    echo "  Puerto: ${POSTGRES_PORT:-5432}"
    echo "  Base de datos: $POSTGRES_DB"
    echo ""
    echo "Bases de datos:"
    echo "  - ${N8N_DB_NAME}"
    echo "  - ${METABASE_DB_NAME}"
    echo "  - ${NOCODB_DB_NAME}"
    echo "  - ${SERVICIOSAF_DB_NAME}"
    echo ""
    echo "Directorios:"
    printf '  - %s\n' "${REQUIRED_DIRS[@]}"
    echo ""
    
    read -p "¿Continuar con la instalación? (s/n): " response
    if [ "$response" != "s" ]; then
        error "Instalación cancelada"
        exit 0
    fi
}

################################################################################
# Restaurar backups usando el script restore.sh
################################################################################

restore_latest_backups() {
    print_step "Restaurando backups más recientes..."
    
    if [ ! -d "${SCRIPT_DIR}/backup" ]; then
        info "No existen backups para restaurar"
        return 0
    fi
    
    local count=$(find "${SCRIPT_DIR}/backup" -name "*.sql" -type f 2>/dev/null | wc -l)
    
    if [ $count -eq 0 ]; then
        info "No se encontraron backups para restaurar"
        return 0
    fi
    
    info "Encontrados $count backup(s). Restaurando..."
    
    # Restaurar n8n_db
    if [ -f "${SCRIPT_DIR}/backup/n8n_db_2025-12-06.sql" ]; then
        info "Restaurando n8n_db..."
        echo "SI" | "${SCRIPT_DIR}/scripts/restore.sh" n8n_db 2025-12-06 >/dev/null 2>&1 && success "n8n_db restaurada" || warning "Error en n8n_db"
    fi
    
    # Restaurar metabase_db
    if [ -f "${SCRIPT_DIR}/backup/metabase_db_2025-12-06.sql" ]; then
        info "Restaurando metabase_db..."
        echo "SI" | "${SCRIPT_DIR}/scripts/restore.sh" metabase_db 2025-12-06 >/dev/null 2>&1 && success "metabase_db restaurada" || warning "Error en metabase_db"
    fi
    
    # Restaurar nocodb_db
    if [ -f "${SCRIPT_DIR}/backup/nocodb_db_2025-12-06.sql" ]; then
        info "Restaurando nocodb_db..."
        echo "SI" | "${SCRIPT_DIR}/scripts/restore.sh" nocodb_db 2025-12-06 >/dev/null 2>&1 && success "nocodb_db restaurada" || warning "Error en nocodb_db"
    fi
    
    # Restaurar serviciosaf_db
    if [ -f "${SCRIPT_DIR}/backup/serviciosaf_db_2025-12-06.sql" ]; then
        info "Restaurando serviciosaf_db..."
        echo "SI" | "${SCRIPT_DIR}/scripts/restore.sh" serviciosaf_db 2025-12-06 >/dev/null 2>&1 && success "serviciosaf_db restaurada" || warning "Error en serviciosaf_db"
    fi
    
    success "Restauración de backups completada"
    echo ""
}

################################################################################
# Iniciar contenedores
################################################################################

start_services() {
    print_step "Iniciando servicios Docker..."
    
    cd "$SCRIPT_DIR"
    
    # Detener contenedores existentes
    info "Deteniendo servicios existentes..."
    docker compose down 2>/dev/null || true
    sleep 2
    
    # Iniciar contenedores
    info "Iniciando contenedores..."
    if docker compose up -d; then
        success "Contenedores iniciados"
    else
        error "Error al iniciar contenedores"
        exit 1
    fi
}

################################################################################
# Verificar estado de servicios
################################################################################

verify_services() {
    print_step "Verificando estado de servicios..."
    
    sleep 5  # Esperar a que los contenedores inicien completamente
    
    # Verificar PostgreSQL
    info "Verificando PostgreSQL..."
    if docker compose exec -T postgres pg_isready -U "$POSTGRES_USER" &>/dev/null; then
        success "PostgreSQL está listo"
    else
        error "PostgreSQL no está respondiendo"
        return 1
    fi
    
    # Verificar Metabase
    info "Verificando Metabase..."
    if docker compose exec -T metabase curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
        success "Metabase está listo"
    else
        warning "Metabase aún está iniciando (esto es normal)"
    fi
    
    # Mostrar estado general
    echo ""
    info "Estado de contenedores:"
    docker compose ps
}

################################################################################
# Mostrar información de acceso
################################################################################

setup_cron_tasks() {
    print_header "CONFIGURACIÓN DE TAREAS PROGRAMADAS"
    
    echo "Las tareas programadas ejecutarán automáticamente:"
    echo "  ${CYAN}• Backup diario${NC} a las 22:00 (10 PM)"
    echo "  ${CYAN}• Actualización semanal${NC} los sábados a las 04:00"
    echo ""
    
    read -p "¿Deseas configurar estas tareas automáticas? (s/n): " setup_cron_response
    
    if [ "$setup_cron_response" = "s" ] || [ "$setup_cron_response" = "S" ]; then
        if [ ! -f "$SCRIPT_DIR/scripts/setup-cron.sh" ]; then
            error "No se encontró $SCRIPT_DIR/scripts/setup-cron.sh"
            warning "Las tareas programadas no serán configuradas"
            return 1
        fi
        
        info "Ejecutando configuración de cron..."
        if sudo "$SCRIPT_DIR/scripts/setup-cron.sh"; then
            success "Tareas programadas configuradas exitosamente"
        else
            warning "Hubo un problema al configurar las tareas programadas"
            warning "Puedes intentarlo manualmente con: sudo $SCRIPT_DIR/scripts/setup-cron.sh"
        fi
    else
        info "Configuración de tareas programadas omitida"
        echo "Puedes configurarlas después ejecutando: ${CYAN}sudo ./scripts/setup-cron.sh${NC}"
    fi
    echo ""
}

show_access_info() {
    print_header "INSTALACIÓN COMPLETADA"
    
    echo "Los servicios están listos. Accede a ellos en:"
    echo ""
    echo -e "${CYAN}Metabase:${NC}"
    echo "  URL: http://localhost:3000"
    echo "  Usuario: admin@example.com"
    echo "  Contraseña: (primera vez pide crear)"
    echo ""
    echo -e "${CYAN}n8n:${NC}"
    echo "  URL: http://localhost:5678"
    echo "  (Necesita configuración inicial)"
    echo ""
    echo -e "${CYAN}NocoDB:${NC}"
    echo "  URL: http://localhost:8080"
    echo "  (Necesita configuración inicial)"
    echo ""
    echo -e "${CYAN}PostgreSQL:${NC}"
    echo "  Host: localhost"
    echo "  Puerto: ${POSTGRES_PORT:-5432}"
    echo "  Usuario: $POSTGRES_USER"
    echo ""
    
    echo "Scripts útiles disponibles en scripts/:"
    echo "  ${CYAN}./backup.sh${NC}       - Hacer backup de todas las bases de datos"
    echo "  ${CYAN}./restore.sh${NC}      - Restaurar una base de datos desde backup"
    echo "  ${CYAN}./update.sh${NC}       - Actualizar contenedores a nuevas versiones"
    echo ""
    
    echo "Comandos útiles:"
    echo "  Ver logs:      ${CYAN}docker compose logs -f${NC}"
    echo "  Detener:       ${CYAN}docker compose down${NC}"
    echo "  Reiniciar:     ${CYAN}docker compose restart${NC}"
    echo "  Ver estado:    ${CYAN}docker compose ps${NC}"
    echo ""
}

################################################################################
# Función principal
################################################################################

main() {
    print_header "INSTALACIÓN - AF CONSTRUCCIONES Y SERVICIOS"
    
    info "Iniciando instalación..."
    info "Directorio: $SCRIPT_DIR"
    echo ""
    
    # Ejecutar pasos de instalación
    check_prerequisites
    create_directories
    migrate_legacy_data
    validate_docker_setup
    load_environment
    show_configuration
    start_services
    verify_services
    
    # Restaurar backups si existen
    restore_latest_backups
    
    show_access_info
    
    # Configurar tareas automáticas
    setup_cron_tasks
    
    success "¡Instalación completada exitosamente!"
    echo ""
}

################################################################################
# Punto de entrada
################################################################################

# Mostrar ayuda
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    cat << EOF
Script de Instalación de AF Construcciones y Servicios

Uso: $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Ejecutar instalación completa
  --help, -h        Mostrar esta ayuda
  --clean           Eliminar todos los contenedores y volúmenes (¡CUIDADO!)
  --reset           Reiniciar servicios
  --restore         Restaurar backups más recientes (con confirmación)
  --status          Ver estado de servicios

Ejemplos:
  $0                # Instalar/configurar completamente
  $0 --status       # Ver estado de servicios
  $0 --reset        # Reiniciar servicios

REQUISITOS:
  - Docker instalado
  - Docker Compose disponible
  - Archivo .env configurado

EOF
    exit 0
fi

# Opciones especiales
case "$1" in
    --clean)
        warning "Eliminando todos los contenedores y volúmenes..."
        read -p "¿Está seguro? (escriba 'SI'): " confirm
        if [ "$confirm" = "SI" ]; then
            cd "$SCRIPT_DIR"
            docker compose down -v
            success "Limpieza completada"
        else
            error "Operación cancelada"
        fi
        exit 0
        ;;
    --reset)
        info "Reiniciando servicios..."
        cd "$SCRIPT_DIR"
        docker compose restart
        success "Servicios reiniciados"
        exit 0
        ;;
    --restore)
        print_header "RESTAURACIÓN DE BACKUPS"
        load_environment
        cd "$SCRIPT_DIR"
        docker compose up -d 2>/dev/null
        restore_latest_backups
        exit 0
        ;;
    --status)
        info "Estado de servicios:"
        cd "$SCRIPT_DIR"
        docker compose ps
        exit 0
        ;;
esac

# Ejecutar instalación
main

exit 0
