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
    
    # Parse DATABASE_URL if available (Heroku provides PostgreSQL, Railway provides MySQL)
    if [ ! -z "$DATABASE_URL" ]; then
        echo "DEBUG: Found DATABASE_URL, parsing..."
        # Handle MySQL URL format: mysql://user:password@host:port/database
        # Also handle mysql2:// format sometimes used by Railway
        if [[ $DATABASE_URL =~ mysql2?://([^:]+):([^@]+)@([^:/?]+):?([0-9]*)/(.+) ]]; then
            DB_USER="${BASH_REMATCH[1]}"
            DB_PASS="${BASH_REMATCH[2]}"
            DB_HOST="${BASH_REMATCH[3]}"
            DB_PORT="${BASH_REMATCH[4]:-3306}"
            DB_NAME="${BASH_REMATCH[5]}"
            
            echo "DEBUG: Setting MySQL connection..."
            echo "  Host: $DB_HOST"
            echo "  Port: $DB_PORT"
            echo "  Database: $DB_NAME"
            sed -i "s|DB_CONNECTION=.*|DB_CONNECTION=mysql|g" .env
            sed -i "s|DB_HOST=.*|DB_HOST=$DB_HOST|g" .env
            sed -i "s|DB_PORT=.*|DB_PORT=$DB_PORT|g" .env
            sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|g" .env
            sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|g" .env
            sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|g" .env
        # Handle PostgreSQL URL format: postgresql://user:password@host:port/database
        elif [[ $DATABASE_URL =~ postgresql://([^:]+):([^@]+)@([^:/?]+):?([0-9]*)/(.+) ]]; then
            DB_USER="${BASH_REMATCH[1]}"
            DB_PASS="${BASH_REMATCH[2]}"
            DB_HOST="${BASH_REMATCH[3]}"
            DB_PORT="${BASH_REMATCH[4]:-5432}"
            DB_NAME="${BASH_REMATCH[5]}"
            
            echo "DEBUG: Setting PostgreSQL connection..."
            sed -i "s|DB_CONNECTION=.*|DB_CONNECTION=pgsql|g" .env
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

# Final debug output before migrations
echo "DEBUG: Final database configuration:"
grep "^DB_CONNECTION\|^DB_HOST\|^DB_PORT\|^DB_DATABASE\|^DB_USERNAME" .env

# Run migrations synchronously
echo "Setting up database..."
php artisan migrate --force 2>&1 || {
    echo "⚠ Migration warning - database may already exist or has other issues"
    echo "Attempting to continue anyway..."
}

echo "✓ Application ready!"
PORT_ENV=${PORT:-8000}
echo "Starting Laravel server on port ${PORT_ENV}..."
exec php artisan serve --host=0.0.0.0 --port=${PORT_ENV}
