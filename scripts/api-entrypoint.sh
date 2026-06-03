#!/bin/sh
set -e

cd /code

# Compute machine signature (required by Plane's instance registration)
HOSTNAME=$(hostname)
MAC=$(ip link show 2>/dev/null | awk '/ether/ {print $2}' | head -n 1 || echo "unknown")
export MACHINE_SIGNATURE=$(echo "${HOSTNAME}${MAC}" | sha256sum | awk '{print $1}')

echo "==> Waiting for database..."
python manage.py wait_for_db

echo "==> Running migrations..."
python manage.py migrate --noinput

echo "==> Setting up instance..."
python manage.py register_instance  "$MACHINE_SIGNATURE" 2>/dev/null || true
python manage.py configure_instance                       2>/dev/null || true
python manage.py clear_cache                              2>/dev/null || true
python manage.py create_bucket                            2>/dev/null || true

echo "==> Collecting static files..."
python manage.py collectstatic --noinput --clear 2>/dev/null || true

echo "==> Starting gunicorn..."
exec gunicorn -w 1 -k uvicorn.workers.UvicornWorker plane.asgi:application \
    --bind 0.0.0.0:8000 \
    --max-requests 1200 \
    --max-requests-jitter 1000 \
    --access-logfile -
