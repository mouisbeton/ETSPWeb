FROM php:8.3-fpm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpq-dev \
    libmariadb-dev \
    zlib1g-dev \
    libzip-dev \
    unzip \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install \
    pdo \
    pdo_mysql \
    zip \
    && docker-php-ext-enable pdo pdo_mysql

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /app

# Copy application files
COPY . .

# Make start script executable
RUN chmod +x start.sh

# Install dependencies
RUN composer install --no-interaction --prefer-dist --optimize-autoloader
RUN npm install
RUN npm run build

# Create cache directories and permissions
RUN mkdir -p storage/framework/{sessions,views,cache,testing} storage/logs \
    && chmod -R 777 storage bootstrap/cache

# Run Laravel caching commands
RUN php artisan config:cache \
    && php artisan route:cache

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

# Start application on port 8000
CMD php -S 0.0.0.0:8000 -t public
