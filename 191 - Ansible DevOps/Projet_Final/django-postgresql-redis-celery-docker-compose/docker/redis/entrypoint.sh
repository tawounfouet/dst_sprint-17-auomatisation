#!/bin/sh
set -eu

: "${REDIS_PASSWORD:?REDIS_PASSWORD is required}"

case "${REDIS_PASSWORD}" in
  *[[:space:]]*)
    echo "REDIS_PASSWORD must not contain whitespace." >&2
    exit 64
    ;;
esac

acl_file=/tmp/datascientest-users.acl
umask 077
printf 'user default on >%s ~* &* +@all\n' "${REDIS_PASSWORD}" > "${acl_file}"

exec redis-server \
  --aclfile "${acl_file}" \
  --appendonly yes \
  --dir /data \
  --protected-mode yes
