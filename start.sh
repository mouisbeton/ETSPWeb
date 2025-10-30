#!/bin/bash
set -e

echo "=== Starting Task Manager ==="

# Detect platform (Heroku or Railway)
if [ ! -z "$DYNO" ]; then
    PLATFORM="HEROKU"
    ENV_FILE=".env.heroku"
elif [ ! -z "$RAILWAY_ENVIRONMENT_NAME" ]; then
    PLATFORM="RAILWAY"
    ENV_FILE=".env.railway"
else
    PLATFORM="LOCAL"
    ENV_FILE=".env"
fi

echo "DEBUG: Detected platform: $PLATFORM"
echo "DEBUG: Using environment file: $ENV_FILE"

# Copy environment file and substitute variables
echo "Setting up environment..."
if [ -f "$ENV_FILE" ]; then
    echo "✓ Found $ENV_FILE - copying to .env"
    cp "$ENV_FILE" .env
    echo "DEBUG: Database credentials from .env.railway:"
    grep "^DB_" .env || true
    
    # Parse DATABASE_URL if available (Railway provides this for MySQL)
    if [ ! -z "$DATABASE_URL" ]; then
        echo "DEBUG: Found DATABASE_URL, parsing..."
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

# Kick migrations in background to avoid blocking boot
(
  echo "Setting up database in background...";
  php artisan migrate --force >> storage/logs/migrate.log 2>&1 || echo "Migration warning - see storage/logs/migrate.log"
) &

echo "✓ Application ready!"
PORT_ENV=${PORT:-8000}
echo "Starting Laravel server on port ${PORT_ENV}..."
exec php artisan serve --host=0.0.0.0 --port=${PORT_ENV}
