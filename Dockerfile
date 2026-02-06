FROM dunglas/frankenphp:1.9-php8.2 AS runtime

RUN install-php-extensions \
    pdo_mysql \
    intl \
    gd \
    zip \
    bcmath \
    opcache \
    pcntl \
    xml \
    simplexml \
    xmlreader \
    iconv \
    zlib \
    pgsql \
    opentelemetry \
    grpc \
    exif


        
COPY composer /usr/bin/composer
COPY composer.json ./

RUN apt update -y && \
    apt install  -y locate nano

RUN composer require \
    open-telemetry/opentelemetry-auto-laravel \
    open-telemetry/sdk \
    open-telemetry/api \
    open-telemetry/exporter-otlp \
    --no-interaction --no-scripts


RUN composer install \
    --no-dev --no-interaction --no-progress --no-scripts --prefer-dist --ignore-platform-reqs \
    && composer clear-cache

RUN { \
    echo "OTEL_SERVICE_NAME=frankenphp"; \
    echo "OTEL_EXPORTER_OTLP_ENDPOINT=http://10.190.13.52:4318"; \
    echo "OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf"; \
    echo "OTEL_TRACES_EXPORTER=otlp"; \
    echo "OTEL_METRICS_EXPORTER=none"; \
    echo "OTEL_LOGS_EXPORTER=none"; \
    echo "OTEL_TRACES_SAMPLER=always_on"; \
    echo "OTEL_LOG_LEVEL=debug"; \
    echo "OTEL_PHP_AUTOLOAD_ENABLED=true"; \
        } > /app/.env


RUN chown www-data:www-data -R /app/vendor

# Set OTEL Environment Variables
ENV OTEL_SERVICE_NAME=frankenphp \
    OTEL_EXPORTER_OTLP_ENDPOINT=http://10.190.13.52:4318 \
    OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf \
    OTEL_TRACES_EXPORTER=otlp \
    OTEL_METRICS_EXPORTER=otlp \
    OTEL_LOGS_EXPORTER=otlp \
    OTEL_TRACES_SAMPLER=always_on \
    OTEL_LOG_LEVEL=debug \
    OTEL_PHP_AUTOLOAD_ENABLED=true

        

    
# docker build -t dunglas/frankenphp-custom:1.9-php8.2.11 .

# -----------------
# stage 2    
# -----------------
# FROM dunglas/frankenphp-custom:1.9-php8.2.11


WORKDIR /applaravel

# Create a new Laravel app (PHP 8.2 compatible)
RUN composer create-project laravel/laravel example-app "10.*" && \
    cd  example-app && \
    composer require laravel/octane && \
    php artisan octane:install --server=frankenphp && \
    frankenphp fmt vendor/laravel/octane/src/Commands/stubs/Caddyfile --overwrite


WORKDIR /applaravel/example-app

RUN mkdir -p storage bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache vendor /config /data .env

#USER www-data
EXPOSE 8080


HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD wget -qO- http://127.0.0.1:8080/health || exit 1

# php artisan --version
# # or
# php artisan -V
# Laravel Framework 10.50.0


# # Update composer.json first, then run:
# composer update

# # Or directly install Laravel 10:
# composer require laravel/framework:^10.0

# php artisan octane:frankenphp
# php artisan serve --host 0.0.0.0
CMD php artisan octane:frankenphp --host=0.0.0.0 --port=8080 --workers=4 --max-requests=500

# docker build -t laravel-franken-php8.2:dev-0.0.1 .
