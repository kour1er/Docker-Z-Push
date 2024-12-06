ARG ALPINE_VERSION=3.19.4
FROM alpine:${ALPINE_VERSION}
ARG ZPUSH_URL=https://github.com/Z-Hub/Z-Push/archive/refs/tags/2.7.4.tar.gz
ENV PHP_VERSION=81
ENV PHP_INI_DIR=/etc/php${PHP_VERSION}
WORKDIR /usr/share/z-push

# Defaults
ENV BACKEND_PROVIDER=BackendIMAP
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
ENV ZPUSH_HOST=push.example.com


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
    php81-mbstring \
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
# --- /var/lib/z-push: log files ---------
# --- /var/log/z-push: state -------------
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

# Link the Z-Push admin tools
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
    mkdir /usr/share/z-push/www && \
    mv /tmp/homepage.html /usr/share/z-push/www/index.html && \
    mv /tmp/supervisord.conf /etc/supervisord.conf && \
    chmod 550 /usr/local/bin/preflight.sh && \
    mkdir -p /run/php${PHP_VERSION}

# -----------------------------------------------
# --- Finishing ---------------------------------
# -----------------------------------------------
# Set permissions
RUN chown -R nginx:nginx \
    /etc/nginx/http.d \
    /etc/nginx/snippets \
    /etc/nginx/nginx.conf \
    /run \
    /usr/share/z-push \
    /var/lib/z-push \
    /var/log/ \
    /usr/local/bin/preflight.sh

USER nginx
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/preflight.sh"]