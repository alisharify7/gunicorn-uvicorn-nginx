#!/bin/sh

set -e

# gunicorn config
export GUNICORN_WORKERS="${GUNICORN_WORKERS:-4}"
export GUNICORN_THREADS="${GUNICORN_THREADS:-2}"
export GUNICORN_TIMEOUT="${GUNICORN_TIMEOUT:-120}"
export GUNICORN_BIND="${GUNICORN_BIND_ADDRESS:-'127.0.0.1'}:${GUNICORN_BIND_PORT:-'8000'}"
export GUNICORN_CMD_ARGS="-k uvicorn.workers.UvicornWorker --bind ${GUNICORN_BIND} --workers ${GUNICORN_WORKERS} --threads ${GUNICORN_THREADS} --timeout ${GUNICORN_TIMEOUT}"


sed "s|\${GUNICORN_BIND_ADDRESS}|${GUNICORN_BIND_ADDRESS:-127.0.0.1}|g" custom.conf | sed "s|\${GUNICORN_BIND_PORT}|${GUNICORN_BIND_PORT:-8000}|g" > /etc/nginx/conf.d/custom.conf
rm /app/custom.conf
rm /app/nginx.conf

nginx -g "daemon off;" &
sleep 2

# Print gunicorn configuration info
echo ""
echo "Starting Gunicorn with the following configuration:"
echo "Workers: ${GUNICORN_WORKERS}"
echo "Threads: ${GUNICORN_THREADS}"
echo "Timeout: ${GUNICORN_TIMEOUT}"
echo "Bind Address: ${GUNICORN_BIND}"
echo "Gunicorn CMD ARGS: ${GUNICORN_CMD_ARGS}"
echo ""

# Start Gunicorn
exec gunicorn main:app ${GUNICORN_CMD_ARGS}
