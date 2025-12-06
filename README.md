# AF Construcciones y Servicios - Stack Docker

Sistema completo de automatización, análisis de datos y gestión integrado en Docker con PostgreSQL, Metabase, n8n y NocoDB.

## 📋 Tabla de Contenidos

- [Requisitos](#requisitos)
- [Instalación Rápida](#instalación-rápida)
- [Configuración del .env](#configuración-del-env)
- [Configuración de Cloudflare Tunnel](#configuración-de-cloudflare-tunnel)
- [Acceso a Servicios](#acceso-a-servicios)
- [Scripts Disponibles](#scripts-disponibles)
- [Solución de Problemas](#solución-de-problemas)

## 🔧 Requisitos

- Docker 20.10+
- Docker Compose 1.29+
- 4GB RAM mínimo
- 20GB espacio en disco

## 🚀 Instalación Rápida

```bash
# 1. Clonar o descargar el repositorio
cd AF

# 2. Ejecutar instalación (crea .env automáticamente si no existe)
./install.sh

# 3. La instalación hará:
#    - Crear estructura de directorios
#    - Generar contraseña segura para PostgreSQL
#    - Descargar imágenes Docker
#    - Iniciar todos los servicios
#    - Restaurar backups si existen
```

## 🔐 Configuración del .env

### Opción 1: Dejar que el script lo configure automáticamente

El script `install.sh` generará automáticamente:
- Contraseña segura de PostgreSQL (32 caracteres aleatorios)
- Variables de n8n con valores por defecto
- Token de Cloudflared (si se proporciona)

### Opción 2: Configuración Manual

Copia `.env.example` a `.env` y edita según tus necesidades:

```bash
cp .env.example .env
nano .env
```

### Variables Principales

#### PostgreSQL

```env
# Usuario administrador de PostgreSQL
POSTGRES_USER=admin

# Contraseña de PostgreSQL (mínimo 12 caracteres)
# Se genera automáticamente si está vacía
POSTGRES_PASSWORD=xC9pLz37gRuV5dK1eWqTf

# Base de datos inicial
POSTGRES_DB=postgres

# Puerto de PostgreSQL (por defecto 5432)
POSTGRES_PORT=5432
```

**Generar contraseña segura:**
```bash
openssl rand -base64 32
```

#### Nombres de Bases de Datos

```env
N8N_DB_NAME=n8n_db
METABASE_DB_NAME=metabase_db
NOCODB_DB_NAME=nocodb_db
SERVICIOSAF_DB_NAME=serviciosaf_db
```

#### Configuración de n8n

```env
# Entorno (production o development)
NODE_ENV=production

# Zona horaria (por defecto Argentina)
TIMEZONE=America/Argentina/Buenos_Aires

# Dominio donde estará n8n
N8N_HOST=n8n.tudominio.com

# Puerto interno (por defecto 5678)
N8N_PORT=5678

# Protocolo (http para desarrollo, https para producción)
N8N_PROTOCOL=https

# URL del webhook
N8N_WEBHOOK_URL=https://n8n.tudominio.com/
```

#### Cloudflare Tunnel

```env
# Token del túnel (obtener de Cloudflare)
CLOUDFLARED_TOKEN=paste_your_token_here
```

## 🌐 Configuración de Cloudflare Tunnel

### Paso 1: Crear Tunnel en Cloudflare

1. Ve a [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Selecciona tu dominio
3. Accede a **Networks > Tunnels** (o **SSL/TLS > Tunnels**)
4. Haz clic en **Create a tunnel**
5. Selecciona **Cloudflared** como conector
6. Asigna un nombre (ej: `af-construcciones`)
7. Copia el token que genera

### Paso 2: Configurar Redireccionamientos

Después de crear el túnel, agrega estos redireccionamientos:

#### Para Metabase
```
Subdomain: meta
Domain: tudominio.com
Type: CNAME
URL: metabase:3000
```

#### Para n8n
```
Subdomain: n8n
Domain: tudominio.com
Type: CNAME
URL: n8n:5678
```

#### Para NocoDB
```
Subdomain: nocodb
Domain: tudominio.com
Type: CNAME
URL: nocodb:8080
```

### Paso 3: Guardar Token en .env

Copia el token en tu `.env`:

```env
CLOUDFLARED_TOKEN=eyJhIjoiMzhlMGNjODEzNTYwNDY2Y2Q5NWIzNmQzZjU5YWU5MmMiLCJ0IjoiMmQzYTUxZmItY2E0Yi00NjIxLWIyMDgtYmFmMWM2MDU5MzRkIiwicyI6Ill2Y0N3Rm9sdVFoZVd1Nkw3L0orNHg0aW45ZURWbi9pN3dJUENhNWo4NmM9In0=
```

## 📱 Acceso a Servicios

### Metabase (Business Intelligence)

**URLs:**
- Local: `http://localhost:3000`
- Remoto: `https://meta.tudominio.com`

**Primer acceso:**
1. Abre la URL
2. Crea cuenta administrador
3. Conecta a PostgreSQL:
   - Host: `postgres`
   - Puerto: `5432`
   - Usuario: Ver `.env` (POSTGRES_USER)
   - Contraseña: Ver `.env` (POSTGRES_PASSWORD)
   - Base de datos: `metabase_db`

### n8n (Automatización)

**URLs:**
- Local: `http://localhost:5678`
- Remoto: `https://n8n.tudominio.com`

**Primer acceso:**
1. Abre la URL
2. Completa configuración inicial
3. Crea tu primera automatización

**Conexión a PostgreSQL en n8n:**
- Host: `postgres`
- Puerto: `5432`
- Usuario: Ver `.env` (POSTGRES_USER)
- Contraseña: Ver `.env` (POSTGRES_PASSWORD)
- Database: Selecciona según necesites

### NocoDB (Gestión de Datos)

**URLs:**
- Local: `http://localhost:8080`
- Remoto: `https://nocodb.tudominio.com`

**Primer acceso:**
1. Abre la URL
2. Crea cuenta
3. Conecta a PostgreSQL:
   - Host: `postgres`
   - Puerto: `5432`
   - Usuario: Ver `.env` (POSTGRES_USER)
   - Contraseña: Ver `.env` (POSTGRES_PASSWORD)

### PostgreSQL

**Conexión directa:**
```bash
psql -h localhost -U admin -d serviciosaf_db
```

**Desde DBeaver, pgAdmin, etc:**
- Host: `localhost`
- Puerto: `5432`
- Usuario: Ver `.env` (POSTGRES_USER)
- Contraseña: Ver `.env` (POSTGRES_PASSWORD)

## 📜 Scripts Disponibles

### install.sh - Instalación Principal

```bash
# Instalación completa (descarga imágenes, crea directorios, inicia servicios)
./install.sh

# Solo ver estado de servicios
./install.sh --status

# Reiniciar servicios
./install.sh --reset

# Restaurar backups más recientes
./install.sh --restore

# Limpiar todo (¡CUIDADO! Elimina contenedores y volúmenes)
./install.sh --clean
```

### scripts/backup.sh - Backup de Bases de Datos

```bash
cd scripts/

# Hacer backup completo de todas las BDs
./backup.sh

# Listar backups disponibles
./backup.sh --list

# Ver estado del último backup
./backup.sh --status
```

Los backups incluyen:
- `n8n_db_YYYY-MM-DD.sql`
- `metabase_db_YYYY-MM-DD.sql`
- `nocodb_db_YYYY-MM-DD.sql`
- `serviciosaf_db_YYYY-MM-DD.sql`

**Nota:** Se eliminan automáticamente los backups más antiguos a 7 días.

### scripts/restore.sh - Restaurar Bases de Datos

```bash
cd scripts/

# Restaurar base de datos con confirmación
./restore.sh n8n_db

# Restaurar fecha específica
./restore.sh metabase_db 2025-12-06

# Listar backups disponibles
./restore.sh --list

# Ver ayuda
./restore.sh --help
```

**Advertencia:** Esta operación elimina completamente la BD existente.

### scripts/update.sh - Actualizar Contenedores

```bash
cd scripts/

# Actualizar imágenes y reiniciar contenedores
./update.sh
```

## 📁 Estructura de Directorios

```
AF/
├── backup/                 # Backups de bases de datos
├── postgres/
│   ├── data/              # Datos persistentes de PostgreSQL
│   └── init/              # Scripts de inicialización
├── n8n_data/              # Datos de n8n
├── nocodb_data/           # Datos de NocoDB
├── docs/                  # Documentación y archivos
├── scripts/
│   ├── backup.sh          # Script de backup
│   ├── restore.sh         # Script de restauración
│   └── update.sh          # Script de actualización
├── docker-compose.yml     # Configuración de servicios
├── .env                   # Variables de entorno (NO commitar)
├── .env.example           # Plantilla de .env
└── install.sh             # Script de instalación
```

## 🔄 Workflow Típico

### Primera Instalación

```bash
# 1. Clonar repositorio
git clone <repo> AF
cd AF

# 2. Ejecutar instalación
./install.sh
# El script creará .env automáticamente con contraseña segura

# 3. Editar .env si necesitas cambios
nano .env

# 4. Reiniciar para aplicar cambios
./install.sh --reset
```

### Desarrollo Diario

```bash
# Ver estado
./install.sh --status

# Ver logs
docker compose logs -f

# Hacer backup (antes de cambios importantes)
cd scripts && ./backup.sh

# Si necesitas restaurar
cd scripts && ./restore.sh n8n_db
```

### Mantenimiento

```bash
# Actualizar imágenes Docker
cd scripts && ./update.sh

# Hacer backup regulares (configurar cron)
# Agregar a crontab:
0 2 * * * cd /home/valeryjl/AF/scripts && ./backup.sh

# Limpiar backups antiguos (se hace automáticamente)
cd scripts && ./backup.sh --clean-logs
```

## 🐛 Solución de Problemas

### PostgreSQL no está listo

```bash
# Ver logs de PostgreSQL
docker compose logs postgres

# Esperar un poco más y reintentar
docker compose restart postgres
```

### Metabase no carga

```bash
# Esperar a que inicie (puede tomar 30-60 segundos)
docker compose logs metabase

# Limpiar y reiniciar
docker compose down
docker compose up -d metabase
```

### Token de Cloudflare inválido

1. Verifica que el token sea correcto en `.env`
2. Revisa la fecha de expiración en Cloudflare
3. Reinicia el contenedor: `docker compose restart cloudflared`

### Backups muy lentos

- Verifica espacio en disco: `df -h`
- Verifica recursos: `docker stats`
- Considera hacer backups en horarios de bajo uso

### Contraseña de PostgreSQL olvidada

Si necesitas reset:

```bash
# 1. Generar nueva contraseña
openssl rand -base64 32

# 2. Actualizar .env
nano .env

# 3. Limpiar datos y reiniciar
./install.sh --clean
./install.sh
```

## 📞 Soporte

Para problemas:

1. Revisa los logs: `docker compose logs <servicio>`
2. Verifica variables en `.env`
3. Intenta reiniciar: `./install.sh --reset`
4. Como último recurso: `./install.sh --clean` y `./install.sh`

## 📄 Licencia

Este proyecto es privado de AF Construcciones y Servicios.

## 📝 Changelog

### v1.0.0 (2025-12-06)
- ✅ Sistema inicial completo
- ✅ Automatización con n8n
- ✅ BI con Metabase
- ✅ Gestión de datos con NocoDB
- ✅ Backup y restauración automática
- ✅ Cloudflare Tunnel integrado

---

**Última actualización:** 6 de diciembre de 2025
