# php-base

A PHP 8.5 runtime image built on [Wolfi](https://github.com/wolfi-dev), with the extensions,
nginx, supervisor and composer needed to run a Laravel application.

```
ghcr.io/rentany/php-base:php8.5
```

## Why it exists

Wolfi is a rolling distro — `apk add` always installs whatever is current. A Dockerfile that
pins a `wolfi-base` digest and then installs packages on top has frozen one half and left the
other moving. They drift, and eventually the packages need a newer glibc than the frozen base
ships:

```
php: /usr/lib/libm.so.6: version `GLIBC_2.44' not found (required by php)
```

That surfaces several layers later as `composer install` exiting 1, which reads like a
dependency problem. It isn't — it's the dynamic linker refusing to start php at all.

Pinning package versions doesn't help either. Wolfi keeps only the newest build of each package,
so `php-8.5=8.5.10-r0` builds today and fails permanently the day 8.5.11 ships.

This image resolves the distro and the packages **in the same build, from the same moment**, so
they can't skew. It's built on demand rather than during a deploy, and it isn't published until
it has proven it runs.

## What's inside

PHP 8.5 with `pdo_pgsql`, `pgsql`, `gd`, `zip`, `intl`, `mbstring`, `pcntl`, `bcmath`,
`sockets`, `exif`, `redis`, `curl`, `xml`, `dom`, `phar`, `openssl`, `fileinfo`, `iconv`,
`simplexml`, `xmlwriter`, `xmlreader`, `soap`, `ctype` — plus php-fpm, nginx, supervisor,
composer, node, git and the postgres client.

`session`, `tokenizer`, `fileinfo`, `ctype` and `opcache` are compiled into PHP core.

## Tags

| Tag | Meaning |
|---|---|
| `php8.5` | rolling — moves when this repo publishes |
| `php8.5-YYYY-MM-DD` | the same image, pinned to a build date |

Consumers track the rolling tag. To roll back a bad base, point the consuming Dockerfile at an
older dated tag and redeploy — no rebuild required.

## Usage

```dockerfile
FROM ghcr.io/rentany/php-base:php8.5

WORKDIR /var/www/html
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-interaction
COPY . .
```

## Publishing

The **Publish** workflow builds with `--no-cache`, verifies `php -v`, `composer`, `php-fpm`,
`nginx` and every required extension, and only then pushes. A base that can't start PHP fails
the run instead of reaching the registry.

It runs on demand, monthly, and when the `Dockerfile` changes.

## Changing the PHP version or adding an extension

1. Edit the `Dockerfile`.
2. Run the **Publish** workflow.
3. Point the consuming Dockerfile at the new tag.

The smoke test is what catches a package Wolfi has renamed or dropped, before anything downstream
sees it.
