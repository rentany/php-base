# PHP 8.5 runtime base — Wolfi, with nginx, supervisor and composer.
#
# Published to ghcr.io/rentany/php-base by .github/workflows/publish.yml. Application images
# start FROM the result, so no packages are resolved while a deploy is running.
#
# ## Why this image exists
#
# Wolfi is a rolling distro: `apk add` always installs whatever is current. An application
# Dockerfile that pins a wolfi-base digest and then installs packages on top has frozen one half
# and left the other moving, and the two drift apart. Both directions have broken a production
# deploy for us:
#
#   * a rolling base moved under a fixed package set  ->  apk add failed outright
#   * a pinned base fell behind the packages          ->  php would not start at all:
#     php: /usr/lib/libm.so.6: version `GLIBC_2.44' not found (required by php)
#
# That second one surfaces several layers later as `composer install` exiting 1, which reads like
# a dependency problem and sends you looking in the wrong place. It is the dynamic linker
# refusing to start php.
#
# Pinning harder does not help. Wolfi keeps only the newest build of each package — older builds
# are removed, not archived — so an exact pin like `php-8.5=8.5.10-r0` works today and fails
# permanently the day 8.5.11 ships. On a rolling repo, exact pinning trades occasional drift for
# guaranteed future breakage.
#
# The fix is to stop resolving packages at deploy time. This image fetches the distro and the
# packages in the same build, from the same moment, so they cannot skew; the smoke test at the
# bottom proves the result runs; and only then is it published. A bad upstream day fails a
# workflow run instead of a deploy.
#
# The base is deliberately NOT digest-pinned here. Pinning it is what caused the second failure
# above, and it would be actively wrong in this file: base and packages must move together.

FROM cgr.dev/chainguard/wolfi-base:latest

# `php-8.5` pins the minor series, which is as far as pinning goes on a rolling repo. The
# published image digest is what carries reproducibility for anything downstream.
#
# session, tokenizer, fileinfo, ctype and opcache are built into PHP core (opcache is mandatory
# in PHP 8.5), so they are not listed.
RUN set -eux; \
    printf 'https://packages.wolfi.dev/os\n' > /etc/apk/repositories; \
    apk update && \
    apk add --no-cache \
        php-8.5 \
        php-8.5-fpm \
        php-8.5-pdo \
        php-8.5-pdo_pgsql \
        php-8.5-pgsql \
        php-8.5-gd \
        php-8.5-zip \
        php-8.5-intl \
        php-8.5-mbstring \
        php-8.5-pcntl \
        php-8.5-bcmath \
        php-8.5-sockets \
        php-8.5-exif \
        php-8.5-redis \
        php-8.5-curl \
        php-8.5-xml \
        php-8.5-dom \
        php-8.5-phar \
        php-8.5-openssl \
        php-8.5-fileinfo \
        php-8.5-iconv \
        php-8.5-simplexml \
        php-8.5-xmlwriter \
        php-8.5-xmlreader \
        php-8.5-soap \
        php-8.5-ctype \
        nodejs \
        nginx \
        supervisor \
        curl \
        git \
        bash \
        postgresql-client \
    && rm -rf /var/cache/apk/* /tmp/*

# Composer from its own official image, rather than a download script or Wolfi's `composer`
# package — the latter pulls its own default PHP alongside the one installed above.
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Fail here, loudly, rather than several layers into an application build.
RUN set -eux; \
    php -v || { echo "FATAL: php cannot start on this base."; exit 1; }; \
    composer --version; \
    for ext in pdo_pgsql gd intl mbstring bcmath redis curl xml soap zip exif sockets pcntl; do \
        php -m | grep -qi "^${ext}$" || { echo "FATAL: php extension missing: ${ext}"; php -m; exit 1; }; \
    done; \
    echo "base image OK: $(php -r 'echo PHP_VERSION;')"
