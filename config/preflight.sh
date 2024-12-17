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
    -e "s|('USE_FULLEMAIL_FOR_LOGIN), false)|('USE_FULLEMAIL_FOR_LOGIN', true)|" \
    -e "s|('PING_INTERVAL', 30)|('PING_INTERVAL', ${PING_INTERVAL})|" \
    -e "s|('LOGLEVEL', LOGLEVEL_INFO)|('LOGLEVEL', LOGLEVEL_${LOGLEVEL})|" \
    -e "s|('LOGAUTHFAIL', false)|('LOGAUTHFAIL', ${LOGAUTHFAIL})|" \
    -e "s|('PING_HIGHER_BOUND_LIFETIME', false)|('PING_HIGHER_BOUND_LIFETIME', ${PING_HIGHER_BOUND_LIFETIME})|" \
    "$MAIN_CONFIG_FILE"

# Update backend imap config file
IMAP_CONFIG_FILE="./backend/imap/config.php"
sed -i \
    -e "s|('IMAP_FOLDER_INBOX', 'INBOX')|('IMAP_FOLDER_INBOX', ${IMAP_FOLDER_INBOX})|" \
    -e "s|('IMAP_FOLDER_SENT', 'SENT')|('IMAP_FOLDER_SENT', ${IMAP_FOLDER_SENT})|" \
    -e "s|('IMAP_FOLDER_DRAFTS', 'DRAFTS')|('IMAP_FOLDER_DRAFTS', ${IMAP_FOLDER_DRAFTS})|" \
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

# Update autodiscover config file
AUTODISCOVER_CONFIG_FILE="./autodiscover/config.php"
sed -i \
    -e "s|// define('ZPUSH_HOST', 'zpush.example.com')|define('ZPUSH_HOST', '${ZPUSH_HOST}')|" \
    -e "s|('TIMEZONE', '')|('TIMEZONE', ${TIMEZONE})|" \
    -e "s|('USE_FULLEMAIL_FOR_LOGIN', false)|('USE_FULLEMAIL_FOR_LOGIN', true)|" \
    -e "s|('LOGLEVEL', LOGLEVEL_INFO)|('LOGLEVEL', LOGLEVEL_${LOGLEVEL})|" \
    -e "s|('BACKEND_PROVIDER', '')|('BACKEND_PROVIDER', '${BACKEND_PROVIDER}')|" \
    "$AUTODISCOVER_CONFIG_FILE"

# Update z-push config file
sed -i "s|server_name localhost|server_name autodiscover.${IMAP_SERVER}|" /etc/nginx/http.d/z-push.conf

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
