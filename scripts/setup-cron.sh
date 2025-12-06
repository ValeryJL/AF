#!/bin/bash

################################################################################
# Script de Configuración de Cron - AF Construcciones y Servicios
# 
# Este script configura tareas programadas automáticamente:
# - Backup diario a las 22:00 (10 PM)
# - Actualización semanal los sábados a las 04:00 (4 AM)
################################################################################

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CRON_FILE="/var/spool/cron/crontabs/$(whoami)"
BACKUP_CMD="cd $PROJECT_DIR && ./scripts/backup.sh >> $PROJECT_DIR/logs/backup.log 2>&1"
UPDATE_CMD="cd $PROJECT_DIR && ./scripts/update.sh >> $PROJECT_DIR/logs/update.log 2>&1"

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
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

################################################################################
# Validaciones
################################################################################

validate_requirements() {
    info "Validando requisitos..."
    
    if [ ! -d "$PROJECT_DIR/scripts" ]; then
        error "No se encontró carpeta scripts en: $PROJECT_DIR"
        exit 1
    fi
    
    if [ ! -f "$PROJECT_DIR/scripts/backup.sh" ]; then
        error "No se encontró backup.sh"
        exit 1
    fi
    
    if [ ! -f "$PROJECT_DIR/scripts/update.sh" ]; then
        error "No se encontró update.sh"
        exit 1
    fi
    
    success "Todos los scripts están disponibles"
}

################################################################################
# Crear directorio de logs
################################################################################

setup_logs() {
    info "Configurando directorio de logs..."
    
    mkdir -p "$PROJECT_DIR/logs"
    
    # Crear archivos de log iniciales
    touch "$PROJECT_DIR/logs/backup.log"
    touch "$PROJECT_DIR/logs/update.log"
    
    success "Directorio de logs creado: $PROJECT_DIR/logs"
}

################################################################################
# Mostrar tareas programadas existentes
################################################################################

show_current_cron() {
    echo ""
    info "Tareas cron actuales:"
    echo ""
    
    if [ -f "$CRON_FILE" ]; then
        grep -E "backup.sh|update.sh" "$CRON_FILE" 2>/dev/null || echo "  (ninguna configurada aún)"
    else
        echo "  (ninguna configurada aún)"
    fi
    
    echo ""
}

################################################################################
# Configurar backup diario
################################################################################

setup_backup_cron() {
    info "Configurando backup diario..."
    
    # Exportar crontab actual a archivo temporal
    crontab -l 2>/dev/null > /tmp/crontab.tmp || true
    
    # Verificar si ya existe la tarea
    if grep -q "backup.sh" /tmp/crontab.tmp 2>/dev/null; then
        warning "Tarea de backup ya existe, removiendo antigua..."
        grep -v "backup.sh" /tmp/crontab.tmp > /tmp/crontab.new
        mv /tmp/crontab.new /tmp/crontab.tmp
    fi
    
    # Agregar nueva tarea de backup (22:00 diariamente)
    echo "0 22 * * * $BACKUP_CMD" >> /tmp/crontab.tmp
    
    # Instalar crontab actualizado
    crontab /tmp/crontab.tmp
    
    success "Backup configurado: Diariamente a las 22:00 (10 PM)"
    info "Comando: $BACKUP_CMD"
}

################################################################################
# Configurar actualización semanal
################################################################################

setup_update_cron() {
    info "Configurando actualización semanal..."
    
    # Exportar crontab actual a archivo temporal
    crontab -l 2>/dev/null > /tmp/crontab.tmp || true
    
    # Verificar si ya existe la tarea
    if grep -q "update.sh" /tmp/crontab.tmp 2>/dev/null; then
        warning "Tarea de update ya existe, removiendo antigua..."
        grep -v "update.sh" /tmp/crontab.tmp > /tmp/crontab.new
        mv /tmp/crontab.new /tmp/crontab.tmp
    fi
    
    # Agregar nueva tarea de update (04:00 los sábados)
    echo "0 4 * * 6 $UPDATE_CMD" >> /tmp/crontab.tmp
    
    # Instalar crontab actualizado
    crontab /tmp/crontab.tmp
    
    success "Actualización configurada: Sábados a las 04:00 (4 AM)"
    info "Comando: $UPDATE_CMD"
}

################################################################################
# Limpiar archivos temporales
################################################################################

cleanup() {
    rm -f /tmp/crontab.tmp /tmp/crontab.new
}

################################################################################
# Mostrar resumen
################################################################################

show_summary() {
    print_header "CONFIGURACIÓN COMPLETADA"
    
    echo -e "${BLUE}📅 Tareas Programadas:${NC}"
    echo ""
    echo -e "${GREEN}✓ Backup diario${NC}"
    echo "  Horario: 22:00 (10 PM) todos los días"
    echo "  Log: $PROJECT_DIR/logs/backup.log"
    echo ""
    echo -e "${GREEN}✓ Actualización semanal${NC}"
    echo "  Horario: 04:00 (4 AM) todos los sábados"
    echo "  Log: $PROJECT_DIR/logs/update.log"
    echo ""
    
    echo -e "${BLUE}📝 Comandos útiles:${NC}"
    echo ""
    echo "  Ver tareas programadas:"
    echo "    ${YELLOW}crontab -l${NC}"
    echo ""
    echo "  Ver logs de backup:"
    echo "    ${YELLOW}tail -f $PROJECT_DIR/logs/backup.log${NC}"
    echo ""
    echo "  Ver logs de actualización:"
    echo "    ${YELLOW}tail -f $PROJECT_DIR/logs/update.log${NC}"
    echo ""
    echo "  Editar tareas programadas:"
    echo "    ${YELLOW}crontab -e${NC}"
    echo ""
    echo "  Remover todas las tareas de este script:"
    echo "    ${YELLOW}./setup-cron.sh --remove${NC}"
    echo ""
}

################################################################################
# Remover configuración de cron
################################################################################

remove_cron() {
    info "Removiendo tareas programadas..."
    
    crontab -l 2>/dev/null > /tmp/crontab.tmp || true
    
    # Remover ambas tareas
    grep -v "backup.sh" /tmp/crontab.tmp > /tmp/crontab.new
    grep -v "update.sh" /tmp/crontab.new > /tmp/crontab.tmp
    
    if [ -s /tmp/crontab.tmp ]; then
        crontab /tmp/crontab.tmp
    else
        crontab -r 2>/dev/null || true
    fi
    
    success "Tareas programadas removidas"
    cleanup
    exit 0
}

################################################################################
# Validar sintaxis de cron
################################################################################

validate_cron_syntax() {
    info "Validando sintaxis de tareas cron..."
    
    # Formato: minuto hora día mes día_semana
    # Backup: 0 22 * * * (22:00 todos los días)
    # Update: 0 4 * * 6 (04:00 sábados)
    
    success "Sintaxis válida"
}

################################################################################
# Función principal
################################################################################

main() {
    print_header "CONFIGURACIÓN DE TAREAS PROGRAMADAS"
    
    # Procesar argumentos
    case "${1:-}" in
        --remove)
            remove_cron
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
    esac
    
    # Ejecutar validaciones
    validate_requirements
    validate_cron_syntax
    
    # Crear estructura
    setup_logs
    
    # Mostrar tareas actuales
    show_current_cron
    
    # Configurar tareas
    setup_backup_cron
    echo ""
    setup_update_cron
    
    # Limpiar temporales
    cleanup
    
    # Mostrar resumen
    show_summary
}

################################################################################
# Ayuda
################################################################################

show_help() {
    cat << EOF
Script de Configuración de Tareas Programadas (Cron)

Uso: $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Configurar backup diario y update semanal
  --remove          Remover todas las tareas programadas
  --help, -h        Mostrar esta ayuda

Tareas que se configuran:
  
  1. BACKUP DIARIO
     Horario: 22:00 (10 PM) todos los días
     Función: Respalda todas las bases de datos
     Log: $(pwd)/logs/backup.log
  
  2. ACTUALIZACIÓN SEMANAL
     Horario: 04:00 (4 AM) todos los sábados
     Función: Actualiza imágenes Docker y reinicia servicios
     Log: $(pwd)/logs/update.log

Ejemplos:
  $0                # Configurar cron
  $0 --remove       # Remover tareas
  $0 --help         # Mostrar ayuda

Ver cron existente:
  crontab -l

Editar cron manualmente:
  crontab -e

Ver logs:
  tail -f $(pwd)/logs/backup.log
  tail -f $(pwd)/logs/update.log

EOF
}

################################################################################
# Punto de entrada
################################################################################

# Si el usuario no es root y no puede escribir en crontab
if [ ! -w /var/spool/cron/crontabs/ ] 2>/dev/null; then
    warning "Este script necesita permisos para modificar crontab"
    warning "Por favor, ejecuta con: sudo $0 $@"
    exit 1
fi

main "$@"

exit 0
