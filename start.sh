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
    
    # For Railway: substitute database variables
    if [ "$PLATFORM" = "RAILWAY" ]; then
        echo "DEBUG: Substituting Railway MySQL environment variables..."
        
        # Railway provides individual env vars - replace placeholders
        if [ ! -z "$MYSQL_HOST" ]; then
            sed -i "s|MYSQL_HOST_PLACEHOLDER|${MYSQL_HOST}|g" .env
            echo "DEBUG: Set DB_HOST=${MYSQL_HOST}"
        fi
        
        if [ ! -z "$MYSQL_PORT" ]; then
            sed -i "s|MYSQL_PORT_PLACEHOLDER|${MYSQL_PORT}|g" .env
            echo "DEBUG: Set DB_PORT=${MYSQL_PORT}"
        fi
        
        if [ ! -z "$MYSQL_DATABASE" ]; then
            sed -i "s|MYSQL_DATABASE_PLACEHOLDER|${MYSQL_DATABASE}|g" .env
            echo "DEBUG: Set DB_DATABASE=${MYSQL_DATABASE}"
        fi
        
        if [ ! -z "$MYSQL_USERNAME" ]; then
            sed -i "s|MYSQL_USERNAME_PLACEHOLDER|${MYSQL_USERNAME}|g" .env
            echo "DEBUG: Set DB_USERNAME=${MYSQL_USERNAME}"
        fi
        
        if [ ! -z "$MYSQL_PASSWORD" ]; then
            sed -i "s|MYSQL_PASSWORD_PLACEHOLDER|${MYSQL_PASSWORD}|g" .env
            echo "DEBUG: Set DB_PASSWORD=***"
        fi
        
        echo "DEBUG: Placeholder substitution complete"
    fi
    
    echo "DEBUG: Final database credentials:"
    grep "^DB_" .env || true
    
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
