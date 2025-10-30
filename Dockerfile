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
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install \
    pdo \
    pdo_mysql \
    zip \
    && docker-php-ext-enable pdo pdo_mysql

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy application files
COPY . .

# Install PHP dependencies
RUN composer install --no-interaction --prefer-dist --optimize-autoloader

# Install Node dependencies
RUN npm install

# Build assets
RUN npm run build

# Create cache directories
RUN mkdir -p storage/framework/{sessions,views,cache,testing} storage/logs \
    && chmod -R 777 storage bootstrap/cache

# Cache Laravel config (skip view:cache for now as it may fail in Docker)
RUN php artisan config:cache \
    && php artisan route:cache

# Expose port
EXPOSE 8000

# Start PHP server with Railway PORT support
CMD ["sh", "-c", "php -S 0.0.0.0:${PORT:-8000} -t public"]
