#!/bin/bash
# Preflight rewrites the config files at runtime and checks some state

# ---------------------------
# --- Configuration files ---
# ---------------------------
# Update main config file
MAIN_CONFIG_FILE="./config.php"
sed -i \
    -e "s|('TIMEZONE', '')|('TIMEZONE', ${TIMEZONE})|" \
    -e "s|('BACKEND_PROVIDER', '')|('BACKEND_PROVIDER', '${BACKEND_PROVIDER}')|" \
    -e "s|('USE_FULLEMAIL_FOR_LOGIN', true)|('USE_FULLEMAIL_FOR_LOGIN', ${FULLEMAIL})|" \
    -e "s|('PING_INTERVAL', 30)|('PING_INTERVAL', ${PING_INTERVAL})|" \
    -e "s|('LOGLEVEL', LOGLEVEL_INFO)|('LOGLEVEL', LOGLEVEL_${LOGLEVEL})|" \
    -e "s|('LOGAUTHFAIL', false)|('LOGAUTHFAIL', ${LOGAUTHFAIL})|" \
    -e "s|('PING_HIGHER_BOUND_LIFETIME', false)|('PING_HIGHER_BOUND_LIFETIME', ${PING_HIGHER_BOUND_LIFETIME})|" \
    -e "s|('LOGFILE', LOGFILEDIR . 'z-push.log')|('LOGFILE', 'php://stdout')|" \
    -e "s|('LOGERRORFILE', LOGFILEDIR . 'z-push-error.log')|('LOGERRORFILE', 'php://stdout')|" \
    "$MAIN_CONFIG_FILE"

# Update backend imap config file
IMAP_CONFIG_FILE="./backend/imap/config.php"
sed -i \
    -e "s|('IMAP_FOLDER_INBOX', 'INBOX')|('IMAP_FOLDER_INBOX', ${IMAP_FOLDER_INBOX})|" \
    -e "s|('IMAP_FOLDER_SENT', 'SENT')|('IMAP_FOLDER_SENT', ${IMAP_FOLDER_SENT})|" \
    -e "s|('IMAP_FOLDER_DRAFT', 'DRAFTS')|('IMAP_FOLDER_DRAFT', ${IMAP_FOLDER_DRAFTS})|" \
    -e "s|('IMAP_FOLDER_TRASH', 'TRASH')|('IMAP_FOLDER_TRASH', ${IMAP_FOLDER_TRASH})|" \
    -e "s|('IMAP_FOLDER_SPAM', 'SPAM')|('IMAP_FOLDER_SPAM', ${IMAP_FOLDER_SPAM})|" \
    -e "s|('IMAP_FOLDER_ARCHIVE', 'ARCHIVE')|('IMAP_FOLDER_ARCHIVE', ${IMAP_FOLDER_ARCHIVE})|" \
    -e "s|('IMAP_SERVER', 'localhost')|('IMAP_SERVER', '${IMAP_SERVER}')|" \
    -e "s|('IMAP_PORT', 143)|('IMAP_PORT', ${IMAP_PORT})|" \
    -e "s|('IMAP_OPTIONS', '/notls/norsh')|('IMAP_OPTIONS', '/ssl/norsh')|" \
    -e "s|('IMAP_FOLDER_CONFIGURED', false)|('IMAP_FOLDER_CONFIGURED', true)|" \
    -e "s|('IMAP_SMTP_METHOD', 'mail')|('IMAP_SMTP_METHOD', 'smtp')|" \
    -e "s|imap_smtp_params = array()|imap_smtp_params = array('host'=>'tcp://${IMAP_SERVER}','port'=>${SMTP_PORT},'auth'=>true,'username'=>'imap_username','password'=>'imap_password')|" \
    "$IMAP_CONFIG_FILE"

if [ "$LDAP_ENABLED" = true ]
then
# Update backend imap config file for LDAP
    echo "LDAP enabled"
    IMAP_CONFIG_FILE="./backend/imap/config.php"
    sed -i \
        -e "s|('IMAP_DEFAULTFROM', '')|('IMAP_DEFAULTFROM', 'ldap')|" \
        -e "s|('IMAP_FROM_LDAP_SERVER_URI', 'ldap://127.0.0.1:389/')|('IMAP_FROM_LDAP_SERVER_URI', '${LDAP_SERVER}/')|" \
        -e "s|('IMAP_FROM_LDAP_USER', 'cn=zpush,ou=servers,dc=zpush,dc=org')|('IMAP_FROM_LDAP_USER', 'cn=${LDAP_USER},ou=people,${LDAP_DOMAIN}')|" \
        -e "s|('IMAP_FROM_LDAP_PASSWORD', 'password')|('IMAP_FROM_LDAP_PASSWORD', '${LDAP_PASSWORD}')|" \
        -e "s|('IMAP_FROM_LDAP_BASE', 'dc=zpush,dc=org')|('IMAP_FROM_LDAP_BASE', '${LDAP_DOMAIN}')|" \
        -e "s|('IMAP_FROM_LDAP_QUERY', '(mail=#username@#domain)')|('IMAP_FROM_LDAP_QUERY', '(mail=#username)')|" \
        "$IMAP_CONFIG_FILE"
    else
        echo "Not using LDAP"
fi

# Update autodiscover config file
AUTODISCOVER_CONFIG_FILE="./autodiscover/config.php"
sed -i \
    -e "s|// define('ZPUSH_HOST', 'zpush.example.com')|define('ZPUSH_HOST', '${ZPUSH_HOST}')|" \
    -e "s|('TIMEZONE', '')|('TIMEZONE', ${TIMEZONE})|" \
    -e "s|('USE_FULLEMAIL_FOR_LOGIN', false)|('USE_FULLEMAIL_FOR_LOGIN', ${FULLEMAIL})|" \
    -e "s|('LOGLEVEL', LOGLEVEL_INFO)|('LOGLEVEL', LOGLEVEL_${LOGLEVEL})|" \
    -e "s|('BACKEND_PROVIDER', '')|('BACKEND_PROVIDER', '${BACKEND_PROVIDER}')|" \
    -e "s|('LOGFILE', LOGFILEDIR . 'autodiscover.log')|('LOGFILE', 'php://stdout')|" \
    -e "s|('LOGERRORFILE', LOGFILEDIR . 'autodiscover-error.log')|('LOGERRORFILE', 'php://stdout')|" \
    "$AUTODISCOVER_CONFIG_FILE"

# Update z-push config file
sed -i "s|server_name localhost|server_name autodiscover.${IMAP_SERVER}|" /etc/nginx/http.d/z-push.conf

# Increase PHP base memory
sed -i "s|memory_limit = 128M|memory_limit = ${PHP_MEMORY}M|" /etc/php${PHP_VERSION}/php.ini

# State check
required_files=(
    "/var/lib/z-push/users"
    "/var/lib/z-push/settings"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        /usr/local/bin/z-push-admin -a fixstates
    fi
done

# Starting supervisord
/usr/bin/supervisord -c /etc/supervisord.conf
