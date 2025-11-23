#!/usr/bin/env bash

set -euxo pipefail

ROOT_DIR=$(pwd)
BUILD_DIR="$ROOT_DIR/build"
INSTALL_DIR="$ROOT_DIR/cmudb/pg-install"
BIN_DIR="$INSTALL_DIR/bin"
POSTGRES_USER="feedback_user"
POSTGRES_PASSWORD="feedback_pass"
POSTGRES_DB="feedback_db"
POSTGRES_PORT=15799

if ! PGPASSWORD=${POSTGRES_PASSWORD} "${BIN_DIR}"/psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -p ${POSTGRES_PORT} -c "SELECT 1" >/dev/null; then
	"${BIN_DIR}"/psql -c "create user ${POSTGRES_USER} with login password '${POSTGRES_PASSWORD}'" postgres -p ${POSTGRES_PORT}
	"${BIN_DIR}"/psql -c "create database ${POSTGRES_DB} with owner = '${POSTGRES_USER}'" postgres -p ${POSTGRES_PORT}
	"${BIN_DIR}"/psql -c "grant pg_monitor to ${POSTGRES_USER}" postgres -p ${POSTGRES_PORT}
	"${BIN_DIR}"/psql -c "alter user ${POSTGRES_USER} with superuser" postgres -p ${POSTGRES_PORT}

	PGPASSWORD=${POSTGRES_PASSWORD} "${BIN_DIR}"/psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -p ${POSTGRES_PORT} --echo-all -f ./cmudb/env/example.sql
fi
PGPASSWORD=${POSTGRES_PASSWORD} "${BIN_DIR}"/psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -p ${POSTGRES_PORT} 
# -XqAt -f ./cmudb/env/explain.sql > fine.json
