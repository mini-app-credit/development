#!/bin/sh
set -e

DB_URL="${DATABASE_WRITE_URL:-postgresql://postgres:postgres@mini-credit-postgres:5432/minicredit}"

DB_HOST=$(echo "$DB_URL" | sed 's/.*@\([^:]*\):.*/\1/')
DB_PORT=$(echo "$DB_URL" | sed 's/.*:\([0-9]*\)\/.*/\1/')
DB_USER=$(echo "$DB_URL" | sed 's/.*:\/\/\([^:]*\):.*/\1/')
DB_PASS=$(echo "$DB_URL" | sed 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/')
DB_NAME=$(echo "$DB_URL" | sed 's/.*\/\([^?]*\).*/\1/')

export PGPASSWORD="$DB_PASS"

echo "Waiting for PostgreSQL at $DB_HOST:$DB_PORT to be ready..."
until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER"; do sleep 1; done

echo "Creating extensions in database $DB_NAME..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c 'CREATE EXTENSION IF NOT EXISTS vector;'
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'

echo "Extensions created successfully!"
