FROM php:8.2-fpm

WORKDIR /var/www
COPY --chmod=755 php-extensions.sh .
RUN ./php-extensions.sh pdo zip exif pcntl gd memcached
RUN sed -i 's/127.0.0.1:9000/0.0.0.0:9000/g' /usr/local/etc/php-fpm.d/www.conf

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

COPY --chown=www-data:www-data ./gds /var/www

USER www-data

RUN ./composer install --optimize-autoloader --no-dev

CMD ["php-fpm"]
