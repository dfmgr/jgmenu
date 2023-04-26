#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317
# shellcheck disable=SC2120
# shellcheck disable=SC2155
# shellcheck disable=SC2199
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202304252038-git
# @@Author           :  Jason Hempstead
# @@Contact          :  jason@casjaysdev.com
# @@License          :  WTFPL
# @@ReadME           :  build.sh --help
# @@Copyright        :  Copyright: (c) 2023 Jason Hempstead, Casjays Developments
# @@Created          :  Tuesday, Apr 25, 2023 20:38 EDT
# @@File             :  build.sh
# @@Description      :
# @@Changelog        :  New script
# @@TODO             :  Better documentation
# @@Other            :
# @@Resource         :
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  other/build
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
APPNAME="jgmenu"                     # Set build name
BUILD_NAME="${BUILD_NAME:-$APPNAME}" # Set build name
VERSION="202304252038-git"           # Set version
USER="${SUDO_USER:-${USER}}"         # Set username
HOME="${USER_HOME:-${HOME}}"         # Set home Directory
SCRIPT_SRC_DIR="${BASH_SOURCE%/*}"   # Set the dir to script
PATH="${PATH//:./}"                  # Remove . from path
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
trap 'exitCode=${exitCode:-0};[ -n "$JGMENU_TEMP_FILE" ] && [ -f "$JGMENU_TEMP_FILE" ] && rm -Rf "$JGMENU_TEMP_FILE" |&__devnull;exit ${exitCode:-0}' EXIT
[ "$1" == "--debug" ] && set -xo pipefail && export SCRIPT_OPTS="--debug" && export _DEBUG="on"
[ "$1" == "--raw" ] && export SHOW_RAW="true"
set -Eo pipefail
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set functions
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__logr() {
  eval "$*" 2>"$JGMENU_LOG_DIR/$APPNAME.log.err" >"$JGMENU_LOG_DIR/$APPNAME.log"
  return $?
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Send all output to /dev/null
__devnull() {
  tee &>/dev/null && exitCode=0 || exitCode=1
  return ${exitCode:-0}
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
# Send errors to /dev/null
__devnull2() {
  [ -n "$1" ] && local cmd="$1" && shift 1 || return 1
  eval $cmd "$*" 2>/dev/null && exitCode=0 || exitCode=1
  return ${exitCode:-0}
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
# See if the executable exists
__cmd_exists() {
  [ -n "$1" ] && local exitCode="" || return 0
  for cmd in "$@"; do
    builtin command -v "$cmd" &>/dev/null && exitCode+=0 || exitCode+=1
  done
  [ $exitCode -eq 0 ] || exitCode=3
  return ${exitCode:-0}
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check for a valid internet connection
__am_i_online() {
  local exitCode=0
  curl -q -LSsfI --max-time 2 --retry 1 "${1:-http://1.1.1.1}" 2>&1 | grep -qi 'server:.*cloudflare' || exitCode=4
  return ${exitCode:-0}
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# colorization
if [ "$SHOW_RAW" = "true" ]; then
  printf_color() { printf '%b\n' "$1" | tr -d '\t' | sed '/^%b$/d;s,\x1B\[ 0-9;]*[a-zA-Z],,g'; }
else
  printf_color() { printf "%b\n" "$(tput setaf "${2:-7}" 2>/dev/null)" "$1" "$(tput sgr0 2>/dev/null)"; }
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# output version
__version() { echo -e ''${GREEN:-}"$VERSION"${NC:-}; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# send notifications
__notifications() {
  __cmd_exists notifications || return
  [ "$JGMENU_NOTIFY_ENABLED" = "yes" ] || return
  [ "$SEND_NOTIFICATION" = "no" ] && return
  (
    set +x
    export SCRIPT_OPTS="" _DEBUG=""
    export NOTIFY_GOOD_MESSAGE="${NOTIFY_GOOD_MESSAGE:-$JGMENU_GOOD_MESSAGE}"
    export NOTIFY_ERROR_MESSAGE="${NOTIFY_ERROR_MESSAGE:-$JGMENU_ERROR_MESSAGE}"
    export NOTIFY_CLIENT_ICON="${NOTIFY_CLIENT_ICON:-$JGMENU_NOTIFY_CLIENT_ICON}"
    export NOTIFY_CLIENT_NAME="${NOTIFY_CLIENT_NAME:-$JGMENU_NOTIFY_CLIENT_NAME}"
    export NOTIFY_CLIENT_URGENCY="${NOTIFY_CLIENT_URGENCY:-$JGMENU_NOTIFY_CLIENT_URGENCY}"
    notifications "$@"
    retval=$?
    return $retval
  ) |& __devnull &
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
printf_readline() {
  local color="$1"
  set -o pipefail
  while read line; do
    printf_color "$line" "${color:-$WHITE}"
  done |& tee
  set +o pipefail
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__help() {
  [ -z "$ARRAY" ] || local array="[${ARRAY//,/ }]"
  [ -z "$LONGOPTS" ] || local opts="[--${LONGOPTS//,/ --}]"
  printf_color "Usage: $APPNAME $opts $array" "$BLUE"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Setup build function
__make_build() {
  local exitCode=1
  local exitCode_make="0"
  local exitCode_cmake="0"
  local exitCode_configure="0"
  if [ -f "$BUILD_SCRIPT_SRC_DIR/CMakeLists.txt" ]; then
    mkdir -p "$BUILD_SCRIPT_SRC_DIR/build" && cd "$BUILD_SCRIPT_SRC_DIR/build" || exit 10
    cmake $CMAKE_ARGS 2>&1 | tee -a "$BUILD_LOG_FILE" |& __devnull || exitCode+=1
    make $MAKE_ARGS 2>&1 | tee -a "$BUILD_LOG_FILE" |& __devnull || exitCode+=1
    sudo make install DESTDIR="$BUILD_DESTDIR" 2>&1 | tee -a "$BUILD_LOG_FILE" |& __devnull || exitCode+=1
    exitCode_cmake="$?"
  elif [ -f "$BUILD_SCRIPT_SRC_DIR/configure" ]; then
    printf_color "Running configure" "$GREEN"
    make clean 2>&1 | tee -a "$BUILD_LOG_FILE" |& __devnull
    ./configure --prefix="$BUILD_DESTDIR" $CONFIGURE_ARGS 2>&1 |
      tee -a "$BUILD_LOG_FILE" |& __devnull
    exitCode_configure="$?"
    if [ -f "$BUILD_SCRIPT_SRC_DIR/Makefile" ]; then
      printf_color "Running make" "$GREEN"
      make $MAKE_ARGS 2>&1 | tee -a "$BUILD_LOG_FILE" |& __devnull || exitCode+=1
      sudo make 2>&1 | tee -a "$BUILD_LOG_FILE" |& __devnull &&
        sudo make install
      exitCode_make="$?"
    fi
  elif [ -f "$BUILD_SCRIPT_SRC_DIR/Makefile" ]; then
    printf_color "Running make" "$GREEN"
    make clean 2>&1 | tee -a "$BUILD_LOG_FILE" |& __devnull
    make $MAKE_ARGS 2>&1 | tee -a "$BUILD_LOG_FILE" |& __devnull || exitCode+=1
    sudo make install DESTDIR="$BUILD_DESTDIR" 2>&1 | tee -a "$BUILD_LOG_FILE" |& __devnull
    exitCode_make="$?"
  fi
  if [ "$exitCode_configure" = 0 ] && [ "$exitCode_make" = 0 ] && [ "$exitCode_cmake" = 0 ]; then
    exitCode=0
  else
    printf_color "Building $BUILD_NAME has failed" "$RED"
    exit 9
  fi
  return "${exitCode:-0}"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
# Set main functions
__run_git() {
  if [ -d "$BUILD_SCRIPT_SRC_DIR/.git" ]; then
    printf_color "Updating the git repo" "$CYAN"
    git -C "$BUILD_SCRIPT_SRC_DIR" reset --hard 2>&1 | tee -a "$BUILD_LOG_FILE" |& __devnull && git -C "$BUILD_SCRIPT_SRC_DIR" pull 2>&1 | tee -a "$BUILD_LOG_FILE" |& __devnull
    if [ $? = 0 ]; then
      return 0
    else
      printf_color "Failed to update: $BUILD_SCRIPT_SRC_DIR" "$RED"
      exit 1
    fi
  elif [ -n "$BUILD_SRC_URL" ]; then
    printf_color "Cloning the git repo to: $BUILD_SCRIPT_SRC_DIR" "$CYAN"
    git clone "$BUILD_SRC_URL" "$BUILD_SCRIPT_SRC_DIR" 2>&1 | tee -a "$BUILD_LOG_FILE" |& __devnull
    if [ $? = 0 ]; then
      return 0
    else
      printf_color "Failed to clone: $BUILD_SRC_URL" "$RED"
      exit 1
    fi
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__check_log() {
  local exitCode="$?"
  if [ -f "$BUILD_LOG_FILE" ]; then
    errors="$(grep -i 'fatal error' "$BUILD_LOG_FILE" || echo '')"
    warnings="$(grep -i 'warning: ' "$BUILD_LOG_FILE" || echo '')"
    if [ -n "$warnings" ]; then
      printf_color "The following warnings have occurred:" "$RED"
      echo -e "$warnings" |& printf_readline
      printf_color "Log file saved to $BUILD_LOG_FILE" "$YELLOW"
      exitCode=0
    fi
    if [ -n "$errors" ] || [ "$exitCode" -ne 0 ]; then
      printf_color "The following errors have occurred:" "$RED"
      echo -e "$errors" |& printf_readline
      printf_color "Log file saved to $BUILD_LOG_FILE" "$YELLOW"
      exitCode=1
    else
      rm -Rf "$BUILD_LOG_FILE" |& __devnull
      printf_color "Build of $BUILD_NAME has completed without error" "$GREEN"
      exitCode=0
    fi
  fi
  return "${exitCode:-0}"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__packages() {
  local exitCode=0
  [ "$PACKAGE_LIST" = " " ] && return
  # Install required packages
  if [ -n "$PACKAGE_LIST" ]; then
    printf_color "Installing required packages" "$BLUE"
    if __cmd_exists pkmgr; then
      for pkg in $PACKAGE_LIST; do
        pkmgr silent install "$pkg" |& __devnull
        [ $? = 0 ] && __logr "Installed $pkg" || { exitCode=$((exitCode + 1)) && __logr "Warning: Failed to installed $pkg"; }
      done
    elif __cmd_exists apt; then
      for pkg in $PACKAGE_LIST; do
        apt install -yy "$pkg" |& __devnull
        [ $? = 0 ] && __logr "Installed $pkg" || { exitCode=$((exitCode + 1)) && __logr "Warning: Failed to installed $pkg"; }
      done
    elif __cmd_exists pacman; then
      for pkg in $PACKAGE_LIST $PACMAN; do
        pacman -S --noconfirm "$pkg" |& __devnull
        [ $? = 0 ] && __logr "Installed $pkg" || { exitCode=$((exitCode + 1)) && __logr "Warning: Failed to installed $pkg"; }
      done
    elif __cmd_exists apt-get; then
      for pkg in $PACKAGE_LIST $APT; do
        apt-get install -yy "$pkg" |& __devnull
        [ $? = 0 ] && __logr "Installed $pkg" || { exitCode=$((exitCode + 1)) && __logr "Warning: Failed to installed $pkg"; }
      done
    elif __cmd_exists apt-get; then
      for pkg in $PACKAGE_LIST $APT; do
        apt-get install -yy "$pkg" |& __devnull
        [ $? = 0 ] && __logr "Installed $pkg" || { exitCode=$((exitCode + 1)) && __logr "Warning: Failed to installed $pkg"; }
      done
    elif __cmd_exists dnf; then
      for pkg in $PACKAGE_LIST $YUM; do
        dnf install -yy "$pkg" |& __devnull
        [ $? = 0 ] && __logr "Installed $pkg" || { exitCode=$((exitCode + 1)) && __logr "Warning: Failed to installed $pkg"; }
      done
    elif __cmd_exists yum; then
      for pkg in $PACKAGE_LIST $YUM; do
        yum install -yy "$pkg" |& __devnull
        [ $? = 0 ] && __logr "Installed $pkg" || { exitCode=$((exitCode + 1)) && __logr "Warning: Failed to installed $pkg"; }
      done
    elif __cmd_exists apk; then
      for pkg in $PACKAGE_LIST $APK; do
        apk add "$pkg" |& __devnull
        [ $? = 0 ] && __logr "Installed $pkg" || { exitCode=$((exitCode + 1)) && __logr "Warning: Failed to installed $pkg"; }
      done
    fi
    [ $exitCode -eq 0 ] && printf_color "Done trying to install packages" "$YELLOW" || printf_color "Installing packages finished with errors" "$YELLOW"
    return $exitCode
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__init() {
  BUILD_BIN="$(builtin type -P "$BUILD_NAME" || echo "$BUILD_NAME")"
  if [ -z "$BUILD_FORCE" ] && __cmd_exists "$BUILD_NAME"; then
    printf_color "$BUILD_NAME is already installed at: ${GREEN}$BUILD_BIN${NC}" "$RED" 1>&2
    printf_color "run with --force to rebuild" "$YELLOW" 1>&2
    exit 0
  fi
  printf_color "Initializing build script for $BUILD_NAME" "$PURPLE"
  printf_color "Saving all output to $BUILD_LOG_FILE" "$CYAN"
  sleep 3
  if command -v "$BUILD_NAME" | grep -q '^/bin' || command -v "$BUILD_NAME" | grep -q '^/usr/bin'; then
    BUILD_DESTDIR="/usr"
  else
    BUILD_DESTDIR="${BUILD_DESTDIR:-/usr/local}"
  fi
  if ! builtin cd "$BUILD_SCRIPT_SRC_DIR"; then
    printf_color "Failed to cd into $BUILD_SCRIPT_SRC_DIR" "$RED"
    exit 1
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check for needed applications
__cmd_exists bash || { printf_color "Missing: bash" "$RED" && exit 1; }
__cmd_exists make || { printf_color "Missing: make" "$RED" && exit 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set variables
exitCode=10
NC="$(tput sgr0 2>/dev/null)"
RESET="$(tput sgr0 2>/dev/null)"
BLACK="\033[0;30m"
RED="\033[1;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"
ORANGE="\033[0;33m"
LIGHTRED='\033[1;31m'
BG_GREEN="\[$(tput setab 2 2>/dev/null)\]"
BG_RED="\[$(tput setab 9 2>/dev/null)\]"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
BUILD_LOG_FILE="${BUILD_LOG_FILE:-/tmp/${BUILD_NAME}_build.log}"
BUILD_SCRIPT_SRC_DIR="${BUILD_SCRIPT_SRC_DIR:-$HOME/.local/share/$BUILD_NAME/source}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
MAKE_ARGS="-j$(nproc) "
CMAKE_ARGS=".. "
CONFIGURE_ARGS=" "
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PACKAGE_LIST=""
PACMAN=""
YUM="cairo-devel xcb-util-devel libxcb-devel xcb-proto xcb-util-image-devel xcb-util-wm-devel"
APT="libxml2-dev libmenu-cache-dev lxmenu-data libpango1.0-dev librsvg2-dev libcairo2-dev libxrandr-dev build-essential git cmake cmake-data pkg-config python3-sphinx libcairo2-dev libxcb1-dev libxcb-util0-dev libxcb-randr0-dev libxcb-composite0-dev python-xcbgen xcb-proto libxcb-image0-dev libxcb-ewmh-dev libxcb-icccm4-dev"
APK=""
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
BUILD_SRC_URL="${BUILD_SRC_URL:-https://github.com/johanmalm/jgmenu}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Application Folders

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Show warning message if variables are missing

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set options
SETARGS="$*"
SHORTOPTS=""
LONGOPTS="debug,force,help,options,raw,version"
ARRAY=""
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Setup application options
setopts=$(getopt -o "$SHORTOPTS" --long "$LONGOPTS" -n "$APPNAME" -- "$@" 2>/dev/null)
eval set -- "${setopts[@]}" 2>/dev/null
while :; do
  case "$1" in
  --debug)
    shift 1
    set -xo pipefail
    export SCRIPT_OPTS="--debug"
    export _DEBUG="on"
    __devnull() { tee || return 1; }
    __devnull2() { eval "$@" |& tee || return 1; }
    ;;
  --help)
    shift 1
    __help
    exit
    ;;
  --version)
    shift 1
    printf_color "$APPNAME Version: $VERSION" "$YELLOW"
    exit
    ;;
  --options)
    echo "--$LONGOPTS" | sed 's|,| --|g'
    exit
    ;;
  --force)
    shift 1
    BUILD_FORCE=true
    ;;
  --)
    shift 1
    break
    ;;
  esac
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Redefine functions based on options

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Additional variables

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Main application
__init
__run_git
__packages
__make_build
__check_log
exitCode=$?
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# check
if { [ "$exitCode" -eq 10 ] || [ "$exitCode" -eq 0 ]; } && [ -n "$(builtin type -P "$BUILD_NAME")" ]; then
  printf_color "Successfully installed $BUILD_NAME" "$GREEN"
  exitCode=0
else
  printf_color "Failed to install $BUILD_NAME" "$RED"
  exitCode=1
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# End application
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# lets exit with code
exit ${exitCode:-0}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# ex: ts=2 sw=2 et filetype=sh
