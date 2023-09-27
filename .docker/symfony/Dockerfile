ARG PHP_VERSION

FROM php:${PHP_VERSION}-fpm

ARG GROUP_ID
ARG USER_ID
ARG XDEBUG_VERSION
ARG GIT_EMAIL
ARG GIT_USERNAME

RUN apt-get update \
	&& apt-get install -y curl \
        wget \
        git \
        vim \
        unzip \
        default-mysql-client \
        zlib1g-dev \
        libzip-dev \
        libfreetype6-dev \
        libpng-dev \
        libjpeg-dev \
        libicu-dev  \
        libonig-dev \
        libxslt1-dev \
  && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-jpeg --with-freetype

RUN docker-php-ext-install \
    pdo pdo_mysql zip xsl gd intl opcache exif mbstring

RUN yes | pecl install xdebug-${XDEBUG_VERSION} \
  && echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > /usr/local/etc/php/conf.d/xdebug.ini \
  && echo "xdebug.mode=debug" >> /usr/local/etc/php/conf.d/xdebug.ini \
  && echo "xdebug.discover_client_host=0" >> /usr/local/etc/php/conf.d/xdebug.ini \
  && echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/xdebug.ini \
  && echo "xdebug.client_port=9003" >> /usr/local/etc/php/conf.d/xdebug.ini \
  && echo "xdebug.log_level=0" >> /usr/local/etc/php/conf.d/xdebug.ini \
  && echo "xdebug.client_host=172.17.0.1" >> /usr/local/etc/php/conf.d/xdebug.ini

ARG SYMFONY_CLI_VERSION
RUN wget https://github.com/symfony-cli/symfony-cli/releases/download/v${SYMFONY_CLI_VERSION}/symfony-cli_linux_amd64.tar.gz \
    && tar -xzvf symfony-cli_linux_amd64.tar.gz \
    && chmod +x symfony \
    && mv symfony /usr/local/bin/

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/

COPY conf/php.ini /usr/local/etc/php/conf.d/100-php.ini

COPY conf/php-fpm.conf /etc/php-fpm.d/php-fpm.conf

RUN groupadd -g "${GROUP_ID}" symfony; \
	useradd -u "${USER_ID}" -m -s /bin/bash -g symfony symfony;

USER symfony

RUN git config --global user.email "${GIT_EMAIL}"
RUN git config --global user.name "${GIT_USERNAME}"

WORKDIR /home/symfony/project