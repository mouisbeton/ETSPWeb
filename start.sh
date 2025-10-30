#!/bin/sh
set -e

PORT=${PORT:-8000}
echo "Starting Laravel server on port $PORT..."
php artisan serve --host=0.0.0.0 --port=$PORT
