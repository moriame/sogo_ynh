#!/bin/bash

#=================================================
# SET ALL CONSTANTS
#=================================================

app=$YNH_APP_INSTANCE_NAME

#=================================================
# DEFINE ALL COMMON FONCTIONS
#=================================================

install_dependance() {
    ynh_install_app_dependencies sogo stunnel4
}

config_sogo() {
    # Avoid if the directory don't exist
    mkdir -p /etc/$app

    ynh_backup_if_checksum_is_different /etc/$app/sogo.conf
    cp ../conf/sogo.conf /etc/$app/sogo.conf

    ynh_replace_string "__APP__" "$app" /etc/$app/sogo.conf
    ynh_replace_string "__ADMINUSER__" "$admin" /etc/$app/sogo.conf
    ynh_replace_string "__DBUSER__" "$db_user" /etc/$app/sogo.conf
    ynh_replace_string "__DBPASS__" "$db_pwd" /etc/$app/sogo.conf
    ynh_replace_string "__PORT__" "$port" /etc/$app/sogo.conf
    ynh_replace_string "__SMTP_PORT__" "$smtp_port" /etc/$app/sogo.conf

    ynh_store_file_checksum /etc/$app/sogo.conf
}

config_stunnel() {
    ynh_backup_if_checksum_is_different /etc/stunnel/$app.conf
    cp ../conf/stunnel.conf /etc/stunnel/$app.conf

    ynh_replace_string "__SMTP_PORT__" "$smtp_port" /etc/stunnel/$app.conf

    ynh_store_file_checksum /etc/stunnel/$app.conf

    # Enable stunnel at startup
    ynh_replace_string "ENABLED=0" "ENABLED=1" /etc/default/stunnel4
}

config_cron() {
    ynh_backup_if_checksum_is_different /etc/cron.d/$app

    cp ../conf/cron /etc/cron.d/$app
    ynh_replace_string "__APP__" "$app" /etc/cron.d/$app
    ynh_store_file_checksum /etc/cron.d/$app
    systemctl restart cron
}

config_nginx() {
    ynh_add_nginx_config

    nginx_domain_path=/etc/nginx/conf.d/$domain.d/*
    nginx_config_path="/etc/nginx/conf.d/$domain.d/$app.conf"

    grep "/principals" $nginx_domain_path || echo "# For IOS 7
location = /principals/ {
    rewrite ^ https://\$server_name/SOGo/dav;
    allow all;
}
" >> "$nginx_config_path"

    grep "/Microsoft-Server-ActiveSync" $nginx_domain_path || echo "# For ActiveSync
location /Microsoft-Server-ActiveSync/ {
    proxy_pass http://127.0.0.1:$port/SOGo/Microsoft-Server-ActiveSync/;
}
" >> "$nginx_config_path"

    ynh_store_file_checksum "$nginx_config_path"

    systemctl reload nginx
}

set_permission() {
    chown -R $app:$app /etc/$app
    chmod u=rwX,g=rX,o= -R /etc/$app
    chown -R $app:$app /var/log/$app
    chmod u=rwX,g=rX,o= -R /var/log/$app
}
