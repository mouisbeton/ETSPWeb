#!/bin/bash
set -e

echo "=== Starting Task Manager on Railway ==="

# Copy environment file and substitute variables
echo "Setting up environment..."
if [ -f .env.railway ]; then
    cp .env.railway .env
    
    # Substitute Railway MySQL environment variables
    sed -i "s|\${MYSQLHOST}|${MYSQLHOST}|g" .env
    sed -i "s|\${MYSQLPORT}|${MYSQLPORT}|g" .env
    sed -i "s|\${MYSQLDATABASE}|${MYSQLDATABASE}|g" .env
    sed -i "s|\${MYSQLUSER}|${MYSQLUSER}|g" .env
    sed -i "s|\${MYSQLPASSWORD}|${MYSQLPASSWORD}|g" .env
    
    echo "✓ Environment configured"
else
    echo "✗ .env.railway not found"
    exit 1
fi

# Clear and cache config
echo "Configuring application..."
php artisan config:clear 2>/dev/null || true
php artisan config:cache

# Run migrations
echo "Setting up database..."
php artisan migrate --force || echo "Migration warning - database may already exist"

echo "✓ Application ready!"
echo "Starting PHP server on port 8000..."
exec php -S 0.0.0.0:8000 -t public
