# Docker-Z-Push
A Docker container for Z-Push, tested against [Docker-Mailserver](https://github.com/docker-mailserver/docker-mailserver).

If you are running Dovecot with auth_username_format = %Lu (i.e. login with full email address) you may experience credential issues on iOS. For more details on this, see [here](https://github.com/Z-Hub/Z-Push/issues/127). As a workaround, you could set auth_default_realm in Dovecot to your domain to resolve this.

If you want to run behind a reverse proxy, something along these lines will probably help:

```
# z-push

server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name zpush.*;
    include /config/nginx/ssl.conf;
    client_max_body_size 0;

    set $forward_scheme http;
    set $server         "SOME_IP";
    set $port           7003;

    location / {
        proxy_pass_request_headers  on;
        proxy_read_timeout          20m;
        keepalive_timeout           10m;
        proxy_pass_header           Date;
        proxy_pass_header           Server;
        proxy_set_header            Host               $host;
        proxy_set_header            X-Real-IP          $remote_addr;
        proxy_set_header            X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header            X-Forwarded-Proto  https;
        proxy_http_version          1.1;
        proxy_set_header            Connection "";
        proxy_buffering             off;
        proxy_next_upstream         error timeout invalid_header http_500 http_502 http_503;
        proxy_redirect              off;

        proxy_pass                          $forward_scheme://$server:$port$request_uri;
    }
}


```
