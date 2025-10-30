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
    
    # Create storage framework directories if they don't exist
    echo "Creating storage directories..."
    mkdir -p storage/framework/{sessions,views,cache,testing}
    mkdir -p storage/logs
    mkdir -p bootstrap/cache
    chmod -R 777 storage bootstrap/cache
    echo "✓ Storage directories created"
    
    # For Railway: substitute ${VAR} style placeholders with actual environment variables
    if [ "$PLATFORM" = "RAILWAY" ]; then
        echo "DEBUG: Substituting Railway MySQL environment variables..."
        
        # Substitute database variables from Railway MySQL service
        sed -i "s|\${RAILWAY_PRIVATE_DOMAIN}|${RAILWAY_PRIVATE_DOMAIN}|g" .env
        sed -i "s|\${MYSQL_DATABASE}|${MYSQL_DATABASE}|g" .env
        sed -i "s|\${MYSQLUSER}|${MYSQLUSER}|g" .env
        sed -i "s|\${MYSQL_ROOT_PASSWORD}|${MYSQL_ROOT_PASSWORD}|g" .env
    fi
    
    echo "DEBUG: Final database credentials:"
    grep "^DB_" .env || true
    
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
    echo "✗ $ENV_FILE not found"
    exit 1
fi

# Clear and cache config
echo "Configuring application..."
php artisan config:clear 2>/dev/null || true
php artisan config:cache

# Final debug output before migrations
echo "DEBUG: Final database configuration:"
grep "^DB_CONNECTION\|^DB_HOST\|^DB_PORT\|^DB_DATABASE\|^DB_USERNAME" .env || true

# Run migrations with error handling
echo "Setting up database..."
php artisan migrate --force 2>&1 || {
    echo "⚠ Migration warning - database may already exist or has other issues"
    echo "Attempting to continue anyway..."
}

echo "✓ Application ready!"
PORT_ENV=${PORT:-8000}
echo "Starting PHP server on port ${PORT_ENV}..."
exec php -S 0.0.0.0:${PORT_ENV} -t public
