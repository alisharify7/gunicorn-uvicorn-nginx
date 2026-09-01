#!/bin/sh

set -eu

log() {
  printf '%s\n' "[entrypoint] $*" >&2
}

fail() {
  log "ERROR: $*"
  exit 64
}

validate_positive_integer() {
  variable_name=$1
  variable_value=$2

  case "$variable_value" in
    ''|*[!0-9]*) fail "$variable_name must be a positive integer (got '$variable_value')" ;;
  esac
  if [ "${#variable_value}" -gt 9 ] || [ "$variable_value" -lt 1 ] 2>/dev/null; then
    fail "$variable_name must be greater than zero and fit in a 32-bit integer (got '$variable_value')"
  fi
}

validate_non_negative_integer() {
  variable_name=$1
  variable_value=$2

  case "$variable_value" in
    ''|*[!0-9]*) fail "$variable_name must be a non-negative integer (got '$variable_value')" ;;
  esac
  if [ "${#variable_value}" -gt 9 ] || [ "$variable_value" -lt 0 ] 2>/dev/null; then
    fail "$variable_name must be zero or greater and fit in a 32-bit integer (got '$variable_value')"
  fi
}

validate_port() {
  variable_name=$1
  variable_value=$2

  case "$variable_value" in
    ''|*[!0-9]*) fail "$variable_name must be a numeric TCP port (got '$variable_value')" ;;
  esac
  if [ "${#variable_value}" -gt 5 ] || [ "$variable_value" -lt 1 ] 2>/dev/null || [ "$variable_value" -gt 65535 ] 2>/dev/null; then
    fail "$variable_name must be between 1 and 65535 (got '$variable_value')"
  fi
}

validate_address() {
  variable_name=$1
  variable_value=$2

  case "$variable_value" in
    ''|*[!A-Za-z0-9._:-]*)
      fail "$variable_name must be a hostname or an IPv4/IPv6 address without brackets (got '$variable_value')"
      ;;
  esac
}

format_host_port() {
  host=$1
  port=$2

  case "$host" in
    *:*) printf '[%s]:%s' "$host" "$port" ;;
    *) printf '%s:%s' "$host" "$port" ;;
  esac
}

APP_MODULE=${APP_MODULE:-main:app}
GUNICORN_WORKER_CLASS=${GUNICORN_WORKER_CLASS:-uvicorn_worker.UvicornWorker}
GUNICORN_WORKERS=${GUNICORN_WORKERS:-2}
GUNICORN_THREADS=${GUNICORN_THREADS:-4}
GUNICORN_TIMEOUT=${GUNICORN_TIMEOUT:-120}
GUNICORN_BIND_ADDRESS=${GUNICORN_BIND_ADDRESS:-127.0.0.1}
GUNICORN_BIND_PORT=${GUNICORN_BIND_PORT:-8000}
NGINX_UPSTREAM_ADDRESS=${NGINX_UPSTREAM_ADDRESS:-127.0.0.1}
NGINX_UPSTREAM_PORT=${NGINX_UPSTREAM_PORT:-$GUNICORN_BIND_PORT}

case "$APP_MODULE" in
  ''|-*|*[![:graph:]]*) fail "APP_MODULE must be a non-empty Gunicorn application URI without whitespace" ;;
esac

validate_address GUNICORN_BIND_ADDRESS "$GUNICORN_BIND_ADDRESS"
validate_port GUNICORN_BIND_PORT "$GUNICORN_BIND_PORT"
validate_address NGINX_UPSTREAM_ADDRESS "$NGINX_UPSTREAM_ADDRESS"
validate_port NGINX_UPSTREAM_PORT "$NGINX_UPSTREAM_PORT"

GUNICORN_BIND=$(format_host_port "$GUNICORN_BIND_ADDRESS" "$GUNICORN_BIND_PORT")
NGINX_UPSTREAM=$(format_host_port "$NGINX_UPSTREAM_ADDRESS" "$NGINX_UPSTREAM_PORT")

case "$NGINX_UPSTREAM_ADDRESS" in
  *:*) nginx_template_address=[$NGINX_UPSTREAM_ADDRESS] ;;
  *) nginx_template_address=$NGINX_UPSTREAM_ADDRESS ;;
esac

if [ -z "${GUNICORN_CMD_ARGS:-}" ]; then
  case "$GUNICORN_WORKER_CLASS" in
    ''|*[!A-Za-z0-9_.:-]*)
      fail "GUNICORN_WORKER_CLASS contains unsupported characters (got '$GUNICORN_WORKER_CLASS')"
      ;;
  esac

  validate_positive_integer GUNICORN_WORKERS "$GUNICORN_WORKERS"
  validate_non_negative_integer GUNICORN_TIMEOUT "$GUNICORN_TIMEOUT"

  GUNICORN_CMD_ARGS="--worker-class $GUNICORN_WORKER_CLASS --bind $GUNICORN_BIND --workers $GUNICORN_WORKERS --timeout $GUNICORN_TIMEOUT"
  if [ "$GUNICORN_WORKER_CLASS" = gthread ]; then
    validate_positive_integer GUNICORN_THREADS "$GUNICORN_THREADS"
    GUNICORN_CMD_ARGS="$GUNICORN_CMD_ARGS --threads $GUNICORN_THREADS"
    log "Gunicorn: app=$APP_MODULE worker=$GUNICORN_WORKER_CLASS bind=$GUNICORN_BIND workers=$GUNICORN_WORKERS threads=$GUNICORN_THREADS timeout=$GUNICORN_TIMEOUT"
  else
    log "Gunicorn: app=$APP_MODULE worker=$GUNICORN_WORKER_CLASS bind=$GUNICORN_BIND workers=$GUNICORN_WORKERS timeout=$GUNICORN_TIMEOUT"
  fi
else
  log "Gunicorn: app=$APP_MODULE with user-supplied GUNICORN_CMD_ARGS"
fi

export APP_MODULE GUNICORN_WORKER_CLASS GUNICORN_WORKERS GUNICORN_THREADS
export GUNICORN_TIMEOUT GUNICORN_BIND_ADDRESS GUNICORN_BIND_PORT GUNICORN_BIND
export GUNICORN_CMD_ARGS NGINX_UPSTREAM_ADDRESS NGINX_UPSTREAM_PORT

template_path=/opt/gunicorn-uvicorn-nginx/custom.conf
if [ -r /app/custom.conf ]; then
  template_path=/app/custom.conf
  log "WARNING: /app/custom.conf is deprecated; replace /opt/gunicorn-uvicorn-nginx/custom.conf instead"
fi
if [ ! -r "$template_path" ]; then
  fail "Nginx server template was not found in /opt/gunicorn-uvicorn-nginx or /app"
fi

server_config_dir=/etc/nginx/server.d
server_config=$server_config_dir/default.conf
server_config_tmp=$server_config.tmp.$$

mkdir -p "$server_config_dir"
trap 'rm -f "$server_config_tmp"' 0
sed \
  -e "s|\${NGINX_UPSTREAM_ADDRESS}|$nginx_template_address|g" \
  -e "s|\${NGINX_UPSTREAM_PORT}|$NGINX_UPSTREAM_PORT|g" \
  "$template_path" > "$server_config_tmp"
mv "$server_config_tmp" "$server_config"
trap - 0

log "Nginx: listen=:80 upstream=$NGINX_UPSTREAM"
nginx -t -c /etc/nginx/nginx.conf

nginx_pid=
gunicorn_pid=
monitor_pid=
shutdown_requested=0

is_alive() {
  [ -n "$1" ] && kill -0 "$1" 2>/dev/null
}

stop_children() {
  if is_alive "$gunicorn_pid"; then
    kill -TERM "$gunicorn_pid" 2>/dev/null || :
  fi
  if is_alive "$nginx_pid"; then
    kill -QUIT "$nginx_pid" 2>/dev/null || :
  fi
}

# Invoked indirectly by the TERM, INT, and QUIT traps below.
# shellcheck disable=SC2329
handle_shutdown() {
  signal_name=$1
  if [ "$shutdown_requested" -eq 0 ]; then
    shutdown_requested=1
    log "Received $signal_name; gracefully stopping Gunicorn and Nginx"
  fi
  if is_alive "$monitor_pid"; then
    kill -TERM "$monitor_pid" 2>/dev/null || :
  fi
  stop_children
}

# Invoked indirectly by the HUP trap below.
# shellcheck disable=SC2329
handle_reload() {
  log "Received HUP; reloading Gunicorn and Nginx"
  if is_alive "$monitor_pid"; then
    kill -TERM "$monitor_pid" 2>/dev/null || :
  fi
  if is_alive "$gunicorn_pid"; then
    kill -HUP "$gunicorn_pid" 2>/dev/null || :
  fi
  if is_alive "$nginx_pid"; then
    kill -HUP "$nginx_pid" 2>/dev/null || :
  fi
}

reap_gunicorn() {
  if [ -n "${gunicorn_status:-}" ]; then
    return
  fi
  if wait "$gunicorn_pid"; then
    gunicorn_status=0
  else
    gunicorn_status=$?
  fi
}

reap_nginx() {
  if [ -n "${nginx_status:-}" ]; then
    return
  fi
  if wait "$nginx_pid"; then
    nginx_status=0
  else
    nginx_status=$?
  fi
}

trap 'handle_shutdown TERM' TERM
trap 'handle_shutdown INT' INT
trap 'handle_shutdown QUIT' QUIT
trap 'handle_reload' HUP

gunicorn "$APP_MODULE" &
gunicorn_pid=$!
nginx -g 'daemon off;' &
nginx_pid=$!

# A signal can arrive between the two launches. Ensure both children observe it.
if [ "$shutdown_requested" -ne 0 ]; then
  stop_children
fi

gunicorn_alive=1
nginx_alive=1
while [ "$gunicorn_alive" -eq 1 ] && [ "$nginx_alive" -eq 1 ]; do
  if is_alive "$gunicorn_pid"; then gunicorn_alive=1; else gunicorn_alive=0; fi
  if is_alive "$nginx_pid"; then nginx_alive=1; else nginx_alive=0; fi

  if [ "$gunicorn_alive" -eq 1 ] && [ "$nginx_alive" -eq 1 ]; then
    sleep 1 &
    monitor_pid=$!
    if wait "$monitor_pid"; then :; else :; fi
    monitor_pid=
  fi
done

gunicorn_status=
nginx_status=

if [ "$shutdown_requested" -ne 0 ]; then
  stop_children
  reap_gunicorn
  reap_nginx
  trap - TERM INT QUIT HUP
  exit 0
fi

# Either service exiting makes the container unhealthy. Stop its peer and report
# the original status (or 1 when a service exited cleanly but unexpectedly).
if [ "$gunicorn_alive" -eq 0 ]; then
  reap_gunicorn
  log "Gunicorn exited unexpectedly with status $gunicorn_status"
fi
if [ "$nginx_alive" -eq 0 ]; then
  reap_nginx
  log "Nginx exited unexpectedly with status $nginx_status"
fi

stop_children
reap_gunicorn
reap_nginx
trap - TERM INT QUIT HUP

if [ "$gunicorn_alive" -eq 0 ] && [ "$gunicorn_status" -ne 0 ]; then
  exit "$gunicorn_status"
fi
if [ "$nginx_alive" -eq 0 ] && [ "$nginx_status" -ne 0 ]; then
  exit "$nginx_status"
fi
exit 1
