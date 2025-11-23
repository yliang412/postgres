#!/bin/bash

set -euxo pipefail

ROOT_DIR=$(pwd)
BUILD_DIR="$ROOT_DIR/build"
INSTALL_DIR="$ROOT_DIR/cmudb/pg-install"
BIN_DIR="$INSTALL_DIR/bin"
PG_CONFIG="$BIN_DIR/pg_config"
POSTGRES_USER="feedback_user"
POSTGRES_PASSWORD="feedback_pass"
POSTGRES_DB="feedback_db"
POSTGRES_PORT=15799



echo "You may want to comment out the configure step if you're not regularly switching between debug and release."
meson setup "$BUILD_DIR" --buildtype=release --prefix "$INSTALL_DIR" -Dllvm=enabled
cd $BUILD_DIR
ninja && ninja install
cd "$ROOT_DIR"
rm -rf "${BIN_DIR}"/pgdata
"${BIN_DIR}"/initdb -D "${BIN_DIR}"/pgdata
cp ./cmudb/env/pgtune.auto.conf "${BIN_DIR}"/pgdata/postgresql.auto.conf

# cd ./contrib/pg_qualstats
# PG_CONFIG=${PG_CONFIG} make clean
# PG_CONFIG=${PG_CONFIG} make
# PG_CONFIG=${PG_CONFIG} make install -j
# cd "${ROOT_DIR}"

cd ./cmudb/extensions/pg_feedback
PG_CONFIG=${PG_CONFIG} make clean
PG_CONFIG=${PG_CONFIG} bear -- make
PG_CONFIG=${PG_CONFIG} make install -j
cd "${ROOT_DIR}"


echo -e "\nshared_preload_libraries = 'auto_explain,pg_feedback'\n" >>"${BIN_DIR}"/pgdata/postgresql.auto.conf
# echo -e "\nshared_preload_libraries = 'pg_stat_statements,pg_qualstats,pg_feedback'\n" >>"${BIN_DIR}"/pgdata/postgresql.auto.conf
echo -e "pg_qualstats.resolve_oids = true\n" >>"${BIN_DIR}"/pgdata/postgresql.auto.conf
echo -e "pg_qualstats.track_constants = true\n" >>"${BIN_DIR}"/pgdata/postgresql.auto.conf
echo -e "pg_qualstats.sample_rate = 1\n" >>"${BIN_DIR}"/pgdata/postgresql.auto.conf

"${BIN_DIR}"/postgres -D "${BIN_DIR}"/pgdata -p ${POSTGRES_PORT}
