ARG ALPINE_VERSION=3.19.4
FROM alpine:${ALPINE_VERSION}

ENV ZPUSH_VERSION=2.7.5
ENV ZPUSH_URL=https://github.com/Z-Hub/Z-Push/archive/refs/tags/${ZPUSH_VERSION}.tar.gz

ENV PHP_VERSION=81
ENV PHP_INI_DIR=/etc/php${PHP_VERSION}

WORKDIR /usr/share/z-push

# Defaults
ENV BACKEND_PROVIDER=BackendIMAP
ENV FULLEMAIL=true
ENV IMAP_FOLDER_ARCHIVE='ARCHIVE'
ENV IMAP_FOLDER_DRAFTS='DRAFTS'
ENV IMAP_FOLDER_INBOX='INBOX'
ENV IMAP_FOLDER_SENT='SENT'
ENV IMAP_FOLDER_SPAM='SPAM'
ENV IMAP_FOLDER_TRASH='DELETED ITEMS'
ENV IMAP_PORT=993
ENV IMAP_SERVER_METHOD=smtp
ENV IMAP_SERVER=example.com
ENV LOGAUTHFAIL=false
ENV LOGLEVEL=WARN
ENV PING_HIGHER_BOUND_LIFETIME=300
ENV PING_INTERVAL=30
ENV SMTP_PORT=587
ENV TIMEZONE='Europe/London'
ENV ZPUSH_HOST=zpush.example.com


# ------------------------
# --- Add dependancies ---
# ------------------------
RUN apk update && apk add --no-cache \
    supervisor \
    curl \
    bash \
    less \
    nano \
    nginx \
    php81 \
    php81-cli \
    php81-curl \
    php81-fpm \
    php81-imap \
    php81-intl \
    php81-ldap \
    php81-mbstring \
    php81-opcache \
    php81-openssl \
    php81-sysvsem \
    php81-sysvshm \
    php81-pcntl \
    php81-pdo \
    php81-posix \
    php81-soap \
    php81-simplexml

# ----------------------------------------
# --- Create three key directories -------
# --- /usr/share/z-push: the libraries ---
# --- /var/log/z-push: log files ---------
# --- /var/lib/z-push: state -------------
# ----------------------------------------
RUN mkdir -p /usr/share/z-push /var/lib/z-push /var/log/z-push && \
    chmod -R 770 /usr/share/z-push /var/lib/z-push /var/log/z-push

# -------------------------------------------
# --- Download Z-Push code from reference ---
# -------------------------------------------
# Download the Z-Push code and make a few alterations
RUN wget -q -O /tmp/zpush.tar.gz ${ZPUSH_URL} && \
    mkdir /tmp/z-push && tar -zvxf /tmp/zpush.tar.gz -C /tmp/z-push --strip-components=1 && \
    cp /tmp/z-push/config/nginx/z-push.conf /etc/nginx/http.d/ && \
    sed -i "s|user nginx|# user nginx|" /etc/nginx/nginx.conf && \
    mkdir /etc/nginx/snippets && \
    cp /tmp/z-push/config/nginx/z-push-php.conf /etc/nginx/snippets/ && \
    echo "fastcgi_pass unix:/run/php-fpm.sock;" >> /etc/nginx/snippets/z-push-php.conf && \
    cp /tmp/z-push/config/nginx/z-push-autodiscover.conf /etc/nginx/snippets/ && \
    cp -r /tmp/z-push/src/* /usr/share/z-push

# Link the Z-Push admin tools and logs
RUN ln -s /usr/bin/php${PHP_VERSION} /usr/sbin/php && \
    ln -s /usr/share/z-push/z-push-admin.php /usr/local/bin/z-push-admin && \
    ln -s /usr/share/z-push/z-push-top.php /usr/local/bin/z-push-top

# ------------------------------------
# --- Config files setup ---
# ------------------------------------
# Copy config files to the container
COPY config/* /tmp

RUN mv /tmp/preflight.sh /usr/local/bin/ && \
    mv /tmp/z-push.conf /etc/nginx/http.d && \
    mv /tmp/fpm-zpush.conf /etc/php81/php-fpm.d/www.conf && \
    mv /tmp/opcache.ini /etc/php${PHP_VERSION}/conf.d/00_opcache.ini && \
    mkdir /usr/share/z-push/www && \
    mv /tmp/homepage.html /usr/share/z-push/www/index.html && \
    mv /tmp/supervisord.conf /etc/supervisord.conf && \
    chmod 550 /usr/local/bin/preflight.sh && \
    mkdir -p /run/php${PHP_VERSION}

# Remove test for logging path because of routing to php://stdout
ENV LOG_PATCH_Z_PUSH="/usr/share/z-push/lib/core/zpush.php"
RUN sed -i \
    -e "s|if ((!file_exists(LOGFILE) && !touch(LOGFILE)) \|\| !is_writable(LOGFILE))||" \
    -e "s|throw new FatalMisconfigurationException(\"The configured LOGFILE can not be modified.\");||" \
    -e "s|if ((!file_exists(LOGERRORFILE) && !touch(LOGERRORFILE)) \|\| !is_writable(LOGERRORFILE))||" \
    -e "s|throw new FatalMisconfigurationException(\"The configured LOGERRORFILE can not be modified.\");||" \
    ${LOG_PATCH_Z_PUSH}
# The autodiscover equivalent
ENV LOG_PATCH_AUTODISCOVER="/usr/share/z-push/autodiscover/autodiscover.php"
RUN sed -i \
    -e "s|if ((!file_exists(LOGFILE) && !touch(LOGFILE)) \|\| !is_writable(LOGFILE))||" \
    -e "s|throw new FatalMisconfigurationException(\"The configured LOGFILE can not be modified.\");||" \
    -e "s|if ((!file_exists(LOGERRORFILE) && !touch(LOGERRORFILE)) \|\| !is_writable(LOGERRORFILE))||" \
    -e "s|throw new FatalMisconfigurationException(\"The configured LOGERRORFILE can not be modified.\");||" \
    ${LOG_PATCH_AUTODISCOVER}
# -----------------------------------------------
# --- Finishing ---------------------------------
# -----------------------------------------------
# Set permissions
RUN chown -R nginx:nginx \
    /etc/nginx/ \
    /etc/php${PHP_VERSION} \
    /run \
    /usr/share/z-push \
    /var/lib/z-push \
    /var/log/ \
    /usr/local/bin/preflight.sh

USER nginx
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/preflight.sh"]
