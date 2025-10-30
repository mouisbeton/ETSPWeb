#!/bin/bash
set -e

echo "=== Starting Task Manager on Railway ==="

# Copy environment file and substitute variables
echo "Setting up environment..."
if [ -f .env.railway ]; then
    cp .env.railway .env
    
    # Parse DATABASE_URL if available (Railway provides this for MySQL)
    if [ ! -z "$DATABASE_URL" ]; then
        # DATABASE_URL format: mysql://user:password@host:port/database
        # Extract components using regex
        if [[ $DATABASE_URL =~ mysql://([^:]+):([^@]+)@([^:]+):([^/]+)/(.+)$ ]]; then
            DB_USER="${BASH_REMATCH[1]}"
            DB_PASS="${BASH_REMATCH[2]}"
            DB_HOST="${BASH_REMATCH[3]}"
            DB_PORT="${BASH_REMATCH[4]}"
            DB_NAME="${BASH_REMATCH[5]}"
            
            sed -i "s|DB_HOST=.*|DB_HOST=$DB_HOST|g" .env
            sed -i "s|DB_PORT=.*|DB_PORT=$DB_PORT|g" .env
            sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|g" .env
            sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|g" .env
            sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|g" .env
        fi
    else
        # Fallback: use individual environment variables if DATABASE_URL not available
        sed -i "s|\${MYSQLHOST}|${MYSQLHOST:-localhost}|g" .env
        sed -i "s|\${MYSQLPORT}|${MYSQLPORT:-3306}|g" .env
        sed -i "s|\${MYSQLDATABASE}|${MYSQLDATABASE:-laravel}|g" .env
        sed -i "s|\${MYSQLUSER}|${MYSQLUSER:-root}|g" .env
        sed -i "s|\${MYSQLPASSWORD}|${MYSQLPASSWORD:-}|g" .env
    fi
    
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
