#!/usr/bin/env bash
set -euo pipefail

# If an .airflow.env file exists at build/copy time, source it so environment variables
# from that file are available to the running container. We export all variables so
# they are present in subsequent processes.
if [ -f /opt/airflow/.airflow.env ]; then
  # shellcheck disable=SC1091
  set -o allexport
  # Use bash source so `KEY=VALUE` lines are exported
  source /opt/airflow/.airflow.env
  set +o allexport
fi

# Exec the original entrypoint from the base image so startup behavior is preserved
exec /entrypoint "$@"
