#!/bin/bash

echo "Starting PHP built-in server on port 8000..."
exec php -S 0.0.0.0:8000 -t public
