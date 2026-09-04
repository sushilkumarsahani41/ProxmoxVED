#!/usr/bin/env bash
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: sushilkumarsahani41
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/sushilkumarsahani41/SharkShell

APP="SharkShell"
var_tags="${var_tags:-ssh;terminal;mcp}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
#var_arm64="${var_arm64:-no}" # unset = ask the user; set yes/no only when verified
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/sharkshell ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "sharkshell" "sushilkumarsahani41/SharkShell"; then
    msg_info "Stopping Service"
    systemctl stop sharkshell
    msg_ok "Stopped Service"

    create_backup /opt/sharkshell/.env

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "sharkshell" "sushilkumarsahani41/SharkShell" "tarball"

    restore_backup

    NODE_VERSION="20" setup_nodejs

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

    msg_info "Configuring Nginx"
    sed -i "s|root /app/public;|root /opt/sharkshell/frontend/dist;|" /opt/sharkshell/nginx.conf
    cp /opt/sharkshell/nginx.conf /etc/nginx/sites-available/sharkshell
    nginx_enable_site sharkshell
    msg_ok "Configured Nginx"

    msg_info "Starting Service"
    systemctl start sharkshell
    msg_ok "Started Service"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}${CL}"
