#!/bin/sh

set -e

FRONTEND_VHOST_CONF="/etc/nginx/conf.d/default.conf"
FRONTEND_INTERFACE_CONF="/usr/share/nginx/html/js/config.js"
DASHBOARD_NGX_VHOST_CONF="/etc/nginx/conf.d/dashboard.php.ngx.conf"


# logging functions
mylog() {
	local type="$1"; shift
	#printf '%s [%s] [Entrypoint]: %s\n' "$(date --rfc-3339=seconds)" "$type" "$*"
	printf '%s [%s] [Entrypoint]: %s\n' "$(date '+%F %T')" "$type" "$*"
}

my_note() {
	mylog Note "$@"
}

my_warn() {
	mylog Warn "$@" >&2
}

my_error() {
	mylog ERROR "$@" >&2
	exit 1
}

render_frontend_interface_settings() {
cat << EOF > ${FRONTEND_INTERFACE_CONF}
const BASE_PATH = {
    php: 'https://${FRONTEND_EXTERNAL_IP}',
    assets: 'https://${FRONTEND_EXTERNAL_IP}/static/'
}
window.BASE_PATH = BASE_PATH;
EOF
}

render_frontend_interface_settings_with_port() {
cat << EOF > ${FRONTEND_INTERFACE_CONF}
const BASE_PATH = {
    php: 'https://${FRONTEND_EXTERNAL_IP}',
    assets: 'https://${FRONTEND_EXTERNAL_IP}/static/'
}
window.BASE_PATH = BASE_PATH;
EOF
}

render_frontend_vhost() {
cat << EOF > ${FRONTEND_VHOST_CONF}
server {
    listen 80;
    server_name ${FRONTEND_EXTERNAL_IP};
    rewrite ^(.*)$ https://${FRONTEND_EXTERNAL_IP};
}

server {
    listen       443 ssl;
    #server_name  x.com;
    server_name  ${FRONTEND_EXTERNAL_IP};
    
    access_log /var/log/nginx/access.log main;
    
    #ssl_certificate /etc/nginx/ssl/server.crt;
    #ssl_certificate_key /etc/nginx/ssl/server.key;

    ssl_certificate /etc/nginx/ssl/ggmails.nl.crt;
    ssl_certificate_key /etc/nginx/ssl/ggmails.nl.p7b;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
        try_files \$uri \$uri/ /index.html;

        location ~ .*\.(gif|jpg|jpeg|png|bmp|swf|flv|mp4|ico)\$ {
            expires 30d;
            #access_log off;
        }

        location ~ .*\.(js|css)?\$ {
            expires 7d;
            #access_log off;
        }
    }

    location /users {
        proxy_pass http://127.0.0.1;
    }

    location /api {
        proxy_pass http://127.0.0.1;
    }

    location /broker {
        proxy_pass http://127.0.0.1;
    }

    location /static/ {
        proxy_pass http://${FILESERVER_INTERNAL_IP}:${FILESERVER_PORT}/;
        proxy_redirect default;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /admin/ {
        sub_filter 'http' 'https';                                     
        sub_filter_once off;
        proxy_pass http://${DASHBOARD_NGX_INTERNAL_IP}:${DASHBOARD_NGX_PORT};
        #proxy_redirect default;
        proxy_redirect http:// https://;              
        proxy_http_version 1.1;              
        proxy_set_header Host \$host;         
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        #add_header Content-Security-Policy "upgrade-insecure-requests";
	}

    location /vendor/ {
        sub_filter 'http' 'https';                                     
        sub_filter_once off;                            
        proxy_pass http://${DASHBOARD_NGX_INTERNAL_IP}:${DASHBOARD_NGX_PORT};
        #proxy_redirect default;
        proxy_redirect http:// https://;      
        proxy_http_version 1.1;     
        proxy_set_header Host \$host;     
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        #add_header Content-Security-Policy "upgrade-insecure-requests";
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF
}

render_dashbord_ngx_vhost() {
cat << EOF > ${DASHBOARD_NGX_VHOST_CONF}
server {
    listen             80;
    server_name        y.com;
    
    proxy_set_header   Host \$host;
    proxy_set_header   X-Real-HOST \$remote_addr;
    proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto \$scheme;

    location / {
        proxy_pass http://${DASHBOARD_NGX_INTERNAL_IP}:${DASHBOARD_NGX_PORT};
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF
}

#modify_dashboard_ngx_vhost() {
#    sed -i "s@proxy_pass.*@proxy_pass http://\"${DASHBOARD_NGX_HOST}\":\"${DASHBOARD_NGX_PORT}\";@g"
#}

# Verify that the minimally required host settings are set for new website.
docker_verify_minimum_env() {
    if [[ -z "${FRONTEND_EXTERNAL_IP}" ]] || [[ -z "${FILESERVER_INTERNAL_IP}" ]] || [[ -z "${FILESERVER_PORT}" ]] || [[ -z "${DASHBOARD_NGX_INTERNAL_IP}" ]] || [[ -z "${DASHBOARD_NGX_PORT}" ]]; then
        my_error $'You must specify FRONTEND_EXTERNAL_IP, FILESERVER_INTERNAL_IP, FILESERVER_PORT, DASHBOARD_NGX_INTERNAL_IP and DASHBOARD_NGX_PORT.'
    fi
}

_main () {
    docker_verify_minimum_env
    render_frontend_interface_settings
    render_frontend_vhost
    render_dashbord_ngx_vhost

    exec "$@"
}


# ###### entrypoint ########
_main "$@"



