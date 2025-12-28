# =============================================================================
# PHP 8.3 FPM Dockerfile for Laravel
# Optimized for production use
# =============================================================================

FROM php:8.3-fpm-alpine

LABEL maintainer="Hagiik hagiihsank@gmail.com"
LABEL description="PHP 8.3 FPM with Laravel extensions"

# Set working directory
WORKDIR /var/www/html

# Install system dependencies
RUN apk add --no-cache \
    # Build dependencies (will be removed later)
    $PHPIZE_DEPS \
    # Required packages
    bash \
    curl \
    git \
    zip \
    unzip \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libwebp-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    postgresql-dev \
    libxml2-dev \
    imagemagick-dev \
    # Node.js for Vite/NPM builds
    nodejs \
    npm \
    # For healthcheck
    fcgi

# Configure and install PHP extensions
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    && docker-php-ext-install -j$(nproc) \
    pdo \
    pdo_pgsql \
    pgsql \
    gd \
    zip \
    intl \
    mbstring \
    exif \
    pcntl \
    bcmath \
    opcache \
    xml \
    soap

# Install PECL extensions
RUN pecl install redis-6.0.2 \
    && pecl install imagick \
    && docker-php-ext-enable redis imagick

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Create non-root user for security
RUN addgroup -g 1000 laravel \
    && adduser -u 1000 -G laravel -h /home/laravel -s /bin/sh -D laravel \
    && adduser laravel www-data

# Set ownership
RUN chown -R laravel:www-data /var/www/html

# Copy PHP-FPM healthcheck script
COPY --chmod=755 <<EOF /usr/local/bin/php-fpm-healthcheck
#!/bin/sh
SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000
EOF

# Cleanup
RUN rm -rf /var/cache/apk/* /tmp/*

# Switch to non-root user (optional, comment out if permission issues)
# USER laravel

# Expose port 9000
EXPOSE 9000

# Start PHP-FPM
CMD ["php-fpm"]
