#!/bin/bash

echo "[INFO] $(date) - Inicio de actualización automática"

# Cargar variables de entorno si tenés un .env
if [ -f ".env" ]; then
  echo "[INFO] Cargando variables desde .env"
  export $(grep -v '^#' .env | xargs)
fi

echo "[INFO] Bajando contenedores..."
docker compose down

echo "[INFO] Actualizando imágenes..."
docker compose pull

echo "[INFO] Levantando servicios..."
docker compose up -d

echo "[INFO] Actualización finalizada correctamente"