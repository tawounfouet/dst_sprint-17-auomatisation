#!/bin/sh
set -eu

: "${DJANGO_SETTINGS_MODULE:?DJANGO_SETTINGS_MODULE must be set explicitly for container runtimes}"
: "${APPLICATION_ENV:?APPLICATION_ENV must be set explicitly for container runtimes}"

case "${APPLICATION_ENV}" in
  dev|stg|prod)
    ;;
  *)
    echo "APPLICATION_ENV must be one of: dev, stg, prod" >&2
    exit 64
    ;;
esac

expected_settings="config.settings.${APPLICATION_ENV}"
if [ "${DJANGO_SETTINGS_MODULE}" != "${expected_settings}" ]; then
  echo "DJANGO_SETTINGS_MODULE must match APPLICATION_ENV: expected ${expected_settings}" >&2
  exit 64
fi

exec "$@"
