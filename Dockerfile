# Рецепт ghcr.io/step3003/php-fpm-alpine:4.1.0 (git-тег v4.1.0), отличие — PHP 8.2.4 → 8.2.35
# (PHP2Shell, CVE-2026-109618, CVE-2026-109619) на базе php:8.2.35-fpm-alpine3.23.
FROM php:8.2.35-fpm-alpine3.23

ENV EXT_REDIS_VERSION=5.3.7
ENV EXT_IGBINARY_VERSION=3.2.7
ENV EXT_ZSTD_VERSION=0.11.0
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
    # на Alpine 3.17 imagemagick тянул все делегаты, на 3.23 они вынесены в подпакеты — возвращаем набор форматов 4.1.0
    imagemagick-heic \
    imagemagick-jxl \
    imagemagick-pango \
    imagemagick-pdf \
    imagemagick-raw \
    imagemagick-svg \
    imagemagick-tiff \
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
    load-source imagick Imagick/imagick $EXT_IMAGICK_VERSION && \
    docker-php-ext-install \
    imagick \
    redis \
    gd \
    zip \
    pdo \
    pdo_pgsql \
    opcache \
    bcmath \
    sockets \
    exif \
    && \
    docker-php-ext-configure ftp --with-openssl-dir=/usr && \
    docker-php-ext-install ftp && \
    rm -rf /usr/src/php-available-exts && \
    apk del .ext-deps && \
    apk del .phpize-deps

COPY --from=composer:2.4.4 /usr/bin/composer /usr/bin/composer

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