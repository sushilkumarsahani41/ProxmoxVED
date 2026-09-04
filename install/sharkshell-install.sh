#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: sushilkumarsahani41
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/sushilkumarsahani41/SharkShell

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y nginx
msg_ok "Installed Dependencies"

PG_VERSION="16" setup_postgresql
PG_DB_NAME="sharkshell" PG_DB_USER="sharkshell" setup_postgresql_db
NODE_VERSION="20" setup_nodejs

fetch_and_deploy_gh_release "sharkshell" "sushilkumarsahani41/SharkShell" "tarball"

msg_info "Configuring Application"
JWT_SECRET=$(openssl rand -hex 32)
ENCRYPTION_KEY=$(openssl rand -hex 32)
cat <<EOF >/opt/sharkshell/.env
# Public URL of this instance. Required behind a TLS-terminating reverse
# proxy or tunnel — without it, OAuth/MCP discovery documents advertise
# the wrong URL. Update after moving behind a domain, then: sharkshell restart
APP_URL=http://${LOCAL_IP}

DB_HOST=127.0.0.1
DB_PORT=5432
DB_USER=${PG_DB_USER}
DB_PASSWORD=${PG_DB_PASS}
DB_NAME=${PG_DB_NAME}

# Upload ceiling (GB) — must match client_max_body_size in
# /etc/nginx/sites-available/sharkshell if you raise it.
MAX_UPLOAD_GB=50
PORT=3002
JWT_SECRET=${JWT_SECRET}
ENCRYPTION_KEY=${ENCRYPTION_KEY}
EOF
msg_ok "Configured Application"

msg_info "Building Frontend"
cd /opt/sharkshell/frontend
$STD npm ci --no-audit --no-fund
$STD npm run build
msg_ok "Built Frontend"

msg_info "Building Backend"
cd /opt/sharkshell/backend
$STD npm ci --ignore-scripts --no-audit --no-fund
$STD npm run build
$STD npm ci --omit=dev --ignore-scripts --no-audit --no-fund
msg_ok "Built Backend"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/sharkshell.service
[Unit]
Description=SharkShell Backend (NestJS)
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/sharkshell/backend
Environment=NODE_ENV=production
Environment=NODE_OPTIONS=--max-old-space-size=512
EnvironmentFile=/opt/sharkshell/.env
ExecStart=/usr/bin/node dist/main.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now sharkshell
msg_ok "Created Service"

msg_info "Configuring Nginx"
sed -i "s|root /app/public;|root /opt/sharkshell/frontend/dist;|" /opt/sharkshell/nginx.conf
cp /opt/sharkshell/nginx.conf /etc/nginx/sites-available/sharkshell
nginx_enable_site sharkshell
msg_ok "Configured Nginx"

motd_ssh
customize
cleanup_lxc
