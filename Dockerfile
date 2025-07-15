ARG ALPINE_VERSION=3.19.4
FROM alpine:${ALPINE_VERSION}

ENV ZPUSH_VERSION=2.7.5
ENV ZPUSH_URL=https://github.com/Z-Hub/Z-Push/archive/refs/tags/${ZPUSH_VERSION}.tar.gz
ENV PHP_VERSION=81
ENV PHP_INI_DIR=/etc/php${PHP_VERSION}

WORKDIR /usr/share/z-push

# Defaults
ENV BACKEND_PROVIDER=BackendIMAP \
    FULLEMAIL=true \
    IMAP_FOLDER_ARCHIVE="Archive" \
    IMAP_FOLDER_DRAFTS="Drafts" \
    IMAP_FOLDER_INBOX="Inbox" \
    IMAP_FOLDER_SENT="Sent" \
    IMAP_FOLDER_SPAM="Spam" \
    IMAP_FOLDER_TRASH="Trash" \
    IMAP_PORT=993 \
    IMAP_SERVER_METHOD=smtp \
    IMAP_SERVER=example.com \
    LOGAUTHFAIL=false \
    LOGLEVEL=WARN \
    PHP_MAX_EXECUTION_TIME=3660 \
    PHP_MEMORY=256 \
    PING_HIGHER_BOUND_LIFETIME=300 \
    PING_INTERVAL=30 \
    PING_LOWER_BOUND_LIFETIME=false \
    RETRY_AFTER_DELAY=300 \
    SMTP_PORT=587 \
    TIMEZONE="Europe/London" \
    ZPUSH_HOST=zpush.example.com

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
    php81-iconv \
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
    php81-simplexml \
    tzdata

# ----------------------------------------
# --- Create three key directories -------
# --- /usr/share/z-push: the libraries ---
# --- /var/log/z-push: log files ---------
# --- /var/lib/z-push: state -------------
# ----------------------------------------
RUN mkdir -p /usr/share/z-push /var/lib/z-push /var/log/z-push && \
    mkdir -p /etc/nginx/snippets && \
    mkdir -p /usr/share/z-push/www && \
    mkdir -p /run/php${PHP_VERSION} && \
    mkdir -p /tmp/z-push

# -------------------------------------------
# --- Download Z-Push code from reference ---
# -------------------------------------------
# Download the Z-Push code and move to correct locations
RUN wget -q -O /tmp/zpush.tar.gz ${ZPUSH_URL} && \
    tar -zxf /tmp/zpush.tar.gz -C /tmp/z-push --strip-components=1 && \
    # cp /tmp/z-push/config/nginx/z-push.conf /etc/nginx/http.d/ && \
    cp /tmp/z-push/config/nginx/z-push-php.conf /etc/nginx/snippets/ && \
    cp /tmp/z-push/config/nginx/z-push-autodiscover.conf /etc/nginx/snippets/ && \
    cp -r /tmp/z-push/src/* /usr/share/z-push && \
    rm -rf /tmp/zpush.tar.gz /tmp/z-push

# ------------------------------------
# --- Config files setup ---
# ------------------------------------
# Copy config files to the container
COPY config/preflight.sh /usr/local/bin/
COPY config/z-push.conf /etc/nginx/http.d/
COPY config/fpm-zpush.conf /etc/php${PHP_VERSION}/php-fpm.d/www.conf
COPY config/opcache.ini /etc/php${PHP_VERSION}/conf.d/00_opcache.ini
COPY config/homepage.html /usr/share/z-push/www/index.html
COPY config/supervisord.conf /etc/supervisord.conf

# Minor alteration for PHP-FPM
RUN sed -i "s|user nginx|# user nginx|" /etc/nginx/nginx.conf && \
    echo "fastcgi_pass unix:/run/php-fpm.sock;" >> /etc/nginx/snippets/z-push-php.conf
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
# Link the Z-Push admin tools and logs
RUN ln -s /usr/bin/php${PHP_VERSION} /usr/sbin/php && \
    ln -s /usr/share/z-push/z-push-admin.php /usr/local/bin/z-push-admin && \
    ln -s /usr/share/z-push/z-push-top.php /usr/local/bin/z-push-top

# Set permissions
RUN chown -R nginx:nginx \
    /etc/nginx/ \
    /etc/php${PHP_VERSION} \
    /run \
    /usr/share/z-push \
    /var/lib/z-push \
    /var/log/ \
    /usr/local/bin/preflight.sh && \
    chmod 550 /usr/local/bin/preflight.sh && \
    chmod -R 770 /usr/share/z-push /var/lib/z-push /var/log/z-push

USER nginx
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/preflight.sh"]
