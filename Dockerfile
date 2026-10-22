# Рецепт восстановлен по слоям ghcr.io/step3003/php-fpm-alpine:8.4.0 (docker history) — в upstream он не опубликован.
# Отличие от 8.4.0 только в базовом образе: PHP 8.4.4 → 8.4.27 (PHP2Shell, CVE-2026-109618, CVE-2026-109619).
FROM php:8.4.27-fpm-alpine3.23

ENV EXT_REDIS_VERSION=6.1.0
ENV EXT_IGBINARY_VERSION=3.2.16
ENV EXT_ZSTD_VERSION=0.14.0
ENV EXT_IMAGICK_VERSION=3.7.0

ARG USER=php
ARG UID=1000
ARG GID=1000

RUN apk update && apk add --no-cache linux-headers \
    curl \
    libzip \
    libjpeg-turbo \
    freetype \
    libwebp \
    libavif \
    zstd \
    imagemagick \
    libpq \
    libgomp

COPY ./helpers/* /usr/local/bin/
RUN apk add --no-cache --update --virtual .ext-deps \
    libpq-dev \
    libzip-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    libavif-dev \
    zstd-dev \
    imagemagick-dev \
    && \
    apk add --no-cache --update --virtual .phpize-deps $PHPIZE_DEPS && \
    load-source igbinary igbinary/igbinary $EXT_IGBINARY_VERSION && \
    load-source zstd kjdev/php-ext-zstd $EXT_ZSTD_VERSION && \
    docker-php-ext-configure zstd --with-libzstd && \
    load-source redis phpredis/phpredis $EXT_REDIS_VERSION && \
    docker-php-ext-install igbinary zstd && \
    docker-php-ext-configure redis --enable-redis-igbinary --enable-redis-zstd && \
    docker-php-ext-configure gd --enable-gd --with-webp --with-jpeg --with-avif --with-freetype && \
    docker-php-ext-install \
    redis \
    gd \
    zip \
    pdo \
    pdo_pgsql \
    opcache \
    bcmath \
    sockets \
    exif

# imagick 3.7.0 не собирается на PHP 8.4 без замены php_strtolower
RUN set -eux && \
    apk add --no-cache \
        imagemagick \
        jpegoptim \
        libwebp \
        libwebp-tools && \
    apk add --no-cache --virtual .imagick-deps \
        $PHPIZE_DEPS \
        imagemagick-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libwebp-dev && \
    curl -L -o /tmp/imagick.tar.gz https://github.com/Imagick/imagick/archive/refs/tags/${EXT_IMAGICK_VERSION}.tar.gz && \
    tar -xzf /tmp/imagick.tar.gz -C /tmp && \
    mv /tmp/imagick-${EXT_IMAGICK_VERSION}* /usr/src/php/ext/imagick && \
    sed -i 's/php_strtolower/zend_str_tolower/g' /usr/src/php/ext/imagick/imagick.c && \
    docker-php-ext-install imagick && \
    rm -rf /tmp/* && \
    apk del .imagick-deps

RUN rm -rf /usr/src/php-available-exts && \
    apk del .ext-deps && \
    apk del .phpize-deps

COPY --from=composer:2.8.6 /usr/bin/composer /usr/bin/composer

RUN addgroup --system --gid $GID $USER && \
    adduser --uid $UID \
        --ingroup $USER \
        --system \
        --disabled-password \
        --home /$USER \
        --shell /bin/ash  \
        $USER \
    && \
    mkdir -p /$USER/app

COPY conf/php-fpm.conf /usr/local/etc/php-fpm.d/www.conf

WORKDIR /$USER/app

USER $USER
