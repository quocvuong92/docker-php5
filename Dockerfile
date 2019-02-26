FROM ubuntu:16.04
MAINTAINER "Vuong Hoang <vuonghq3@fpt.com.vn>"

ENV OS_LOCALE="en_US.UTF-8" \
    DEBIAN_FRONTEND=noninteractive

# Update & Ensure UTF-8
RUN apt-get update && apt-get install -y locales tzdata && locale-gen ${OS_LOCALE}
ENV LANG=${OS_LOCALE} \
    LANGUAGE=${OS_LOCALE} \
    LC_ALL=${OS_LOCALE} \
    NGINX_CONF_DIR=/etc/nginx

ENV TZ 'Asia/Ho_Chi_Minh'

ENV PHP_RUN_DIR=/run/php \
    PHP_LOG_DIR=/var/log/php \
    PHP_CONF_DIR=/etc/php/5.6 \
    PHP_DATA_DIR=/var/lib/php

# Setup timezone & install libraries
RUN echo $TZ > /etc/timezone && rm -rf /etc/localtime &&  ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && dpkg-reconfigure -f noninteractive tzdata \
	&& apt-get install -y language-pack-en-base \
	&& BUILD_DEPS='software-properties-common python-software-properties' \
	&& dpkg-reconfigure locales \
	&&  apt-get install --no-install-recommends -y $BUILD_DEPS \
	&& add-apt-repository -y ppa:ondrej/php \
	&& apt-get update \
	# Install softwares
	&& apt-get install -y curl wget vim nginx net-tools build-essential python-pip supervisor \
	# Install php 5.6
	&& apt-get install -y php5.6-fpm php5.6-cli php5.6-intl \
	   php5.6-zip php5.6-mbstring php5.6-xml php5.6-json php5.6-curl \
	   php5.6-mcrypt php5.6-gd php5.6-pgsql php5.6-mysql php-pear \
	   php5.6-geoip php5.6-redis php5.6-sqlite php5.6-xml php5.6-xmlrpc \
	   php5.6-xdebug php5.6-mongo php5.6-mysql php5.6-pgsql \
    	   php5.6-memcached php5.6-memcache php5.6-dev\
        # Advanced sofwares
	#	   php5.6-dev php-pear phpunit zlib1g-dev file swig python2.7 python-dev python-pip \
	#        && pecl install grpc-1.12.0 \
        && phpenmod mcrypt \
    # Install composer
        && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
        && mkdir -p ${PHP_LOG_DIR} ${PHP_RUN_DIR} \
    # Install nginx
    && wget -O - http://nginx.org/keys/nginx_signing.key | apt-key add - \
	&& echo "deb http://nginx.org/packages/ubuntu/ xenial nginx" | tee -a /etc/apt/sources.list \
	&& echo "deb-src http://nginx.org/packages/ubuntu/ xenial nginx" | tee -a /etc/apt/sources.list \
	&& apt-get update \
	&& apt-get install -y nginx \
	&& rm -rf  ${NGINX_CONF_DIR}/sites-enabled/* ${NGINX_CONF_DIR}/sites-available/* \
    # Install supervisor
     && apt-get install -y supervisor && mkdir -p /var/log/supervisor \
     && ln -sf /dev/stdout /var/log/nginx/access.log \
     && ln -sf /dev/stderr /var/log/nginx/error.log \
    # Cleaning
    && apt-get purge -y --auto-remove $BUILD_DEPS \
    && apt-get autoremove -y && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
# Copy supervisor conf and app
ADD ./supervisord.conf /etc/

COPY ./app /var/www/app/

COPY ./configs/php-fpm.conf ${PHP_CONF_DIR}/fpm/php-fpm.conf
COPY ./configs/www.conf ${PHP_CONF_DIR}/fpm/pool.d/www.conf
COPY ./configs/php.ini ${PHP_CONF_DIR}/fpm/conf.d/custom.ini

COPY ./configs/nginx.conf ${NGINX_CONF_DIR}/nginx.conf
COPY ./configs/app.conf ${NGINX_CONF_DIR}/sites-enabled/app.conf


RUN sed -i "s~PHP_RUN_DIR~${PHP_RUN_DIR}~g" ${PHP_CONF_DIR}/fpm/php-fpm.conf \
    && sed -i "s~PHP_LOG_DIR~${PHP_LOG_DIR}~g" ${PHP_CONF_DIR}/fpm/php-fpm.conf \
    && chown www-data:www-data ${PHP_DATA_DIR} -Rf

# PHP_DATA_DIR store sessions
VOLUME ["${PHP_RUN_DIR}", "${PHP_DATA_DIR}"]

WORKDIR /var/www/app

EXPOSE 80 443
#CMD ["/usr/bin/supervisord"]
ENTRYPOINT ["supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]
