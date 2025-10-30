#!/bin/sh
set -e

PORT=${PORT:-8000}
echo "Starting PHP server on port $PORT..."
php -S 0.0.0.0:$PORT -t public
