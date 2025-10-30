#!/bin/bash

# Set default port
PORT=${PORT:-8000}

# Validate port is a number
if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    PORT=8000
fi

echo "Starting PHP built-in server on port $PORT..."
exec php -S 0.0.0.0:$PORT -t public
