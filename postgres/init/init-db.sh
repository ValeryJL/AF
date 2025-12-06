#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE n8n_db;
    CREATE DATABASE metabase_db;
    CREATE DATABASE nocodb_db;
    CREATE DATABASE serviciosaf_db;
EOSQL
