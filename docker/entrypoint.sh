#!/usr/bin/env bash
set -e
# shellcheck source=docker/setup.bash
source /usr/local/share/ecen537/setup.bash
exec "$@"
