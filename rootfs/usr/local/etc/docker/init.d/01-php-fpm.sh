#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
[ "$DEBUGGER" = "on" ] && echo "Enabling debugging" && set -o pipefail -x$DEBUGGER_OPTIONS || set -o pipefail
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
export PATH="/usr/local/etc/docker/bin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# run trap command on exit
trap 'retVal=$?;[ "$SERVICE_IS_RUNNING" != "true" ] && [ -f "/run/init.d/$EXEC_CMD_BIN.pid" ] && rm -Rf "/run/init.d/$EXEC_CMD_BIN.pid";exit $retVal' SIGINT SIGTERM EXIT
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# import the functions file
if [ -f "/usr/local/etc/docker/functions/entrypoint.sh" ]; then
  . "/usr/local/etc/docker/functions/entrypoint.sh"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# import variables
for set_env in "/root/env.sh" "/usr/local/etc/docker/env"/*.sh "/config/env"/*.sh; do
  [ -f "$set_env" ] && . "$set_env"
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Custom functions

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# execute command variables
# Working directory for the service process
WORKDIR=""
# User ID to run service as
SERVICE_UID="0"
# Execute command as this user
SERVICE_USER="daemon"
# Port the service listens on
SERVICE_PORT="9000"
# Binary to execute
EXEC_CMD_BIN="php-fpm"
# Arguments to pass to php-fpm
EXEC_CMD_ARGS="--allow-to-run-as-root --nodaemonize --fpm-config /etc/php/php-fpm.conf"
# Function to exit appropriately based on context
__script_exit() {
  local exit_code="${1:-0}"
  if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    # Script is being sourced - use return
    return "$exit_code"
  else
    # Script is being executed - use exit
    exit "$exit_code"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Optional message to display before executing the service
PRE_EXEC_MESSAGE=""
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Other variables that are needed
data_dir="/data"
conf_dir="/config/php"
www_dir="${WWW_ROOT_DIR:-/data/htdocs}"
etc_dir="${PHP_INI_DIR:-$(__find_php_ini)}"
php_bin="${PHP_BIN_DIR:-$(__find_php_bin)}"
php_user="$SERVICE_USER"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# use this function to update config files - IE: change port
__update_conf_files() {
  echo "Initializing php in $conf_dir"
  if [ -n "$php_bin" ]; then
    [ -d "/data/logs/php" ] || \mkdir -p "/data/logs/php"
    \chmod -Rf 777 "$data_dir/logs/php" /var/tmp
    # Seed /config/php from discovered php etc dir on first start (copy only)
    __init_service_conf "$conf_dir" "$etc_dir"
    # Symlink /etc/php -> /config/php so /etc always reflects user config
    if [ ! -L "$etc_dir" ]; then
      \rm -rf "$etc_dir"
      \ln -sf "$conf_dir" "$etc_dir"
    fi
    # Also normalize /etc/php if etc_dir differs (distros vary)
    if [ "$etc_dir" != "/etc/php" ] && [ ! -L "/etc/php" ]; then
      \ln -sf "$conf_dir" "/etc/php"
    fi
    # Flat /etc/ symlinks so /etc/php.ini, /etc/php-fpm.conf, /etc/php-fpm.d always exist
    [ -L "/etc/php.ini" ] || [ -e "/etc/php.ini" ] || \ln -sf "/etc/php/php.ini" "/etc/php.ini"
    [ -L "/etc/php-fpm.conf" ] || [ -e "/etc/php-fpm.conf" ] || \ln -sf "/etc/php/php-fpm.conf" "/etc/php-fpm.conf"
    [ -L "/etc/php-fpm.d" ] || [ -e "/etc/php-fpm.d" ] || \ln -sf "/etc/php/php-fpm.d" "/etc/php-fpm.d"
    #
    if [ -f "$www_dir/www/index.html" ] && [ -f "$www_dir/www/index.php" ]; then
      \rm -Rf "$www_dir/www/index.html"
    fi
    \chmod -Rf 777 "/data/logs/php"
    #
    \sed -i 's|user.*=.*|user = '"$php_user"'|g' "$conf_dir"/*/www.conf
    \sed -i 's|group.*=.*|group = '"$php_user"'|g' "$conf_dir"/*/www.conf
    \chown -Rf "$php_user" "$conf_dir" "$data_dir/logs/php" /var/tmp
  else
    echo "php can not be found"
    [ -f "$www_dir/info.php" ] && echo "PHP support is not enabled" >"$www_dir/info.php"
    __script_exit 1
  fi

  return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# use this function to setup ssl support
__update_ssl_conf() {

  return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# function to run before executing
__pre_execute() {
  grep -s -q "$php_user:" "/etc/passwd" && chown -Rf $php_user:$php_user "$etc_dir" "/data/logs/php" && echo "changed ownership to $user"

  return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# script to start server
__run_start_script() {
  local workdir="${WORKDIR:-$HOME}"
  local cmd="$EXEC_CMD_BIN $EXEC_CMD_ARGS"
  local user="${SERVICE_USER:-root}"
  local lc_type="${LC_ALL:-${LC_CTYPE:-$LANG}}"
  local home="${workdir//\/root/\/home\/docker}"
  local path="/usr/local/bin:/usr/bin:/bin:/usr/sbin"
  case "$1" in
  check) shift 1 && __pgrep $EXEC_CMD_BIN || return 5 ;;
  *) su_cmd env -i PWD="$home" HOME="$home" LC_CTYPE="$lc_type" PATH="$path" USER="$user" sh -c "$cmd" || return 10 ;;
  esac
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Allow ENV_ variable
# Import env file
[ -f "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh" ] && "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# change to directory
WORKDIR="${ENV_WORKDIR:-$WORKDIR}"
# execute command as another user
SERVICE_USER="${ENV_SERVICE_USER:-$SERVICE_USER}"
# set the user id
SERVICE_UID="${ENV_SERVICE_UID:-$SERVICE_UID}"
# port which service is listening on
SERVICE_PORT="${ENV_SERVICE_PORT:-$SERVICE_PORT}"
# command to execute
EXEC_CMD_BIN="${ENV_EXEC_CMD_BIN:-$EXEC_CMD_BIN}"
# command arguments
EXEC_CMD_ARGS="${ENV_EXEC_CMD_ARGS:-$EXEC_CMD_ARGS}"
# Show message before execute
PRE_EXEC_MESSAGE="${ENV_PRE_EXEC_MESSAGE:-$PRE_EXEC_MESSAGE}"
# default exit code
SERVICE_EXIT_CODE=0
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
printf '%s\n' "# - - - Attempting to start $EXEC_CMD_BIN - - - #"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# ensure the command exists
if [ ! -f "$(type -P "$EXEC_CMD_BIN")" ] && [ -z "$EXEC_CMD_BIN" ]; then
  echo "$EXEC_CMD_BIN is not a valid command"
  exit 2
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if __pgrep "$EXEC_CMD_BIN"; then
  SERVICE_IS_RUNNING="true"
  echo "$EXEC_CMD_BIN is running"
  exit 0
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# show message if env exists
if [ -n "$EXEC_CMD_BIN" ]; then
  [ -n "$SERVICE_USER" ] && echo "Setting up service to run as $SERVICE_USER"
  [ -n "$SERVICE_PORT" ] && echo "$EXEC_CMD_BIN will be running on $SERVICE_PORT"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Change to working directory
[ -n "$WORKDIR" ] && mkdir -p "$WORKDIR" && __cd "$WORKDIR" && echo "Changed to $PWD"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Initialize ssl
__update_ssl_conf
__update_ssl_certs
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Updating config files
__update_conf_files
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# run the pre execute commands
[ -n "$PRE_EXEC_MESSAGE" ] && echo "$PRE_EXEC_MESSAGE"
__pre_execute
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
WORKDIR="${WORKDIR:-}"
if [ "$SERVICE_USER" = "root" ] || [ -z "$SERVICE_USER" ]; then
  su_cmd() { eval "$@" || return 1; }
elif [ "$(builtin type -P gosu)" ]; then
  su_cmd() { gosu $SERVICE_USER "$@" || return 1; }
elif [ "$(builtin type -P runuser)" ]; then
  su_cmd() { runuser -u $SERVICE_USER "$@" || return 1; }
elif [ "$(builtin type -P sudo)" ]; then
  su_cmd() { sudo -u $SERVICE_USER "$@" || return 1; }
elif [ "$(builtin type -P su)" ]; then
  su_cmd() { su -s /bin/sh - $SERVICE_USER -c "$@" || return 1; }
else
  echo "Can not switch to $SERVICE_USER: attempting to run as root"
  su_cmd() { eval "$@" || return 1; }
fi
if [ -n "$WORKDIR" ] && [ "${SERVICE_USER:-$USER}" != "root" ]; then
  echo "Fixing file permissions"
  su_cmd chown -Rf $SERVICE_USER $WORKDIR $etc_dir $var_dir $log_dir
fi
if __pgrep $EXEC_CMD_BIN && [ -f "/run/init.d/$EXEC_CMD_BIN.pid" ]; then
  SERVICE_EXIT_CODE=1
  echo "$EXEC_CMD_BIN" is already running
else
  echo "Starting service: $EXEC_CMD_BIN $EXEC_CMD_ARGS"
  su_cmd touch /run/init.d/$EXEC_CMD_BIN.pid
  __run_start_script "$@" |& tee -a "/tmp/entrypoint.log"
  if [ "$?" -ne 0 ]; then
    echo "Failed to execute: $EXEC_CMD_BIN $EXEC_CMD_ARGS"
    SERVICE_EXIT_CODE=10 SERVICE_IS_RUNNING="false"
    su_cmd rm -Rf "/run/init.d/$EXEC_CMD_BIN.pid"
  fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__script_exit $SERVICE_EXIT_CODE
