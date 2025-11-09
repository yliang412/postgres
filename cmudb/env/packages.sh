#!/usr/bin/env bash

## =============================================================================
## POSTGRES DEVELOPMENT SETUP
##
## This script will setup necessary environment for PostgreSQL development.
##
## Tested on Ubuntu 24.04
## =============================================================================

# Strict mode
set -euo pipefail
IFS=$'\t\n'

sudo apt update -y

## PostgreSQL
sudo apt install -y \
  build-essential libreadline-dev zlib1g-dev flex bison libxml2-dev libxslt-dev libssl-dev libxml2-utils xsltproc ccache pkg-config

## Clang toolchain
sudo apt install -y libclang-dev

## Rust Toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "${HOME}/.cargo/env"
cargo install --force cargo-binstall
cargo binstall --force cbindgen

## Python Environment
sudo apt install python3.12-venv
python3 -m venv pg-venv
