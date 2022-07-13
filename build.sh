#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version       : 202207042115-git
# @Author        : Jason Hempstead
# @Contact       : jason@casjaysdev.com
# @License       : LICENSE.md
# @ReadME        : build.sh --help
# @Copyright     : Copyright: (c) 2022 Jason Hempstead, Casjays Developments
# @Created       : Tuesday, Jul 05, 2022 07:56 EDT
# @File          : build.sh
# @Description   : Installer script for jgmenu
# @TODO          :
# @Other         :
# @Resource      :
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
APPNAME="$(basename "$0")"
VERSION="202207042115-git"
USER="${SUDO_USER:-${USER}}"
HOME="${USER_HOME:-${HOME}}"
SRC_DIR="${BASH_SOURCE%/*}"
PATH="${PATH//:./}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
if [[ "$1" == "--debug" ]]; then shift 1 && set -xo pipefail && export SCRIPT_OPTS="--debug" && export _DEBUG="on"; fi
trap 'exitCode=${exitCode:-$?};[ -n "$BUILD_SH_TEMP_FILE" ] && [ -f "$BUILD_SH_TEMP_FILE" ] && rm -Rf "$BUILD_SH_TEMP_FILE" &>/dev/null;exit ${exitCode:-$?}' EXIT
set -Eo pipefail

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Setup build function
__make_build() {
  local exitCode=1
  local exitCode_make="0"
  local exitCode_cmake="0"
  local exitCode_configure="0"
  if [[ -f "$BUILD_SRC_DIR/CMakeLists.txt" ]]; then
    mkdir -p "$BUILD_SRC_DIR/build" && cd "$BUILD_SRC_DIR/build" || exit 10
    cmake .. 2>&1 | tee -a "$BUILD_LOG_FILE" &>/dev/null || exitCode+=1
    make -j$(nproc) 2>&1 | tee -a "$BUILD_LOG_FILE" &>/dev/null || exitCode+=1
    sudo make install DESTDIR="$BUILD_DESTDIR" 2>&1 | tee -a "$BUILD_LOG_FILE" &>/dev/null || exitCode+=1
    exitCode_cmake="$?"
  elif [[ -f "$BUILD_SRC_DIR/configure" ]]; then
    __printf_color "$GREEN" "Running configure"
    make clean 2>&1 | tee -a "$BUILD_LOG_FILE" &>/dev/null
    ./configure \
      --prefix="$BUILD_DESTDIR" \
      --with-lx \
      --with-pmenu 2>&1 |
      tee -a "$BUILD_LOG_FILE" &>/dev/null
    exitCode_configure="$?"
    if [[ -f "$BUILD_SRC_DIR/Makefile" ]]; then
      __printf_color "$GREEN" "Running make"
      make -j$(nproc) 2>&1 | tee -a "$BUILD_LOG_FILE" &>/dev/null || exitCode+=1
      sudo make 2>&1 | tee -a "$BUILD_LOG_FILE" &>/dev/null &&
        sudo make install
      exitCode_make="$?"
    fi
  elif [[ -f "$BUILD_SRC_DIR/Makefile" ]]; then
    __printf_color "$GREEN" "Running make"
    make clean 2>&1 | tee -a "$BUILD_LOG_FILE" &>/dev/null
    make -j$(nproc) 2>&1 | tee -a "$BUILD_LOG_FILE" &>/dev/null || exitCode+=1
    sudo make install DESTDIR="$BUILD_DESTDIR" 2>&1 | tee -a "$BUILD_LOG_FILE" &>/dev/null
    exitCode_make="$?"
  fi
  if [[ "$exitCode_configure" = 0 ]] && [[ "$exitCode_make" = 0 ]] && [[ "$exitCode_cmake" = 0 ]]; then
    exitCode=0
  else
    __printf_color "$RED" "Building $BUILD_NAME has failed"
    exit 9
  fi
  return "${exitCode:-$?}"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
# Set main functions
__run_git() {
  if [[ -d ".git" ]]; then
    __printf_color "$CYAN" "Updating the git repo"
    git reset --hard 2>&1 | tee -a "$BUILD_LOG_FILE" &>/dev/null || exitCode+=1
    git pull 2>&1 | tee -a "$BUILD_LOG_FILE" &>/dev/null
    if [[ $? = 0 ]]; then
      return 0
    else
      __printf_color "$RED" "Failed to update: $BUILD_SRC_DIR"
      exit 1
    fi
  elif [[ -n "$BUILD_SRC_URL" ]]; then
    __printf_color "$CYAN" "Cloning the git repo to: $BUILD_SRC_DIR"
    git clone "$BUILD_SRC_URL" "$BUILD_SRC_DIR" 2>&1 | tee -a "$BUILD_LOG_FILE" &>/dev/null
    if [[ $? = 0 ]]; then
      return 0
    else
      __printf_color "$RED" "Failed to clone: $BUILD_SRC_URL"
      exit 1
    fi
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__check_log() {
  local exitCode="$?"
  if [[ -f "$BUILD_LOG_FILE" ]]; then
    errors="$(grep -i 'fatal error' "$BUILD_LOG_FILE" || echo '')"
    warnings="$(grep -i 'warning: ' "$BUILD_LOG_FILE" || echo '')"
    if [[ -n "$warnings" ]]; then
      __printf_color "$RED" "The following warnings have occurred:"
      echo -e "$warnings"
      __printf_color "$YELLOW" "Log file saved to $BUILD_LOG_FILE"
      exitCode=0
    fi
    if [[ -n "$errors" ]] || [[ "$exitCode" -ne 0 ]]; then
      __printf_color "$RED" "The following errors have occurred:"
      echo -e "$errors"
      __printf_color "$YELLOW" "Log file saved to $BUILD_LOG_FILE"
      exitCode=1
    else
      rm -Rf "$BUILD_LOG_FILE" &>/dev/null
      __printf_color "$GREEN" "Build of $BUILD_NAME has completed without error"
      exitCode=0
    fi
  fi
  return "${exitCode:-$?}"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__packages() {
  # Install required packages
  __printf_color "$BLUE" "Installing required packages"
  if cmd_exists apt-get; then
    if cmd_exists pkmgr; then
      for pkg in libxml2-dev libmenu-cache-dev lxmenu-data libpango1.0-dev librsvg2-dev libcairo2-dev libxrandr-dev build-essential git cmake cmake-data pkg-config python3-sphinx libcairo2-dev libxcb1-dev libxcb-util0-dev libxcb-randr0-dev libxcb-composite0-dev python-xcbgen xcb-proto libxcb-image0-dev libxcb-ewmh-dev libxcb-icccm4-dev; do
        pkmgr silent install "$pkg" &>/dev/null
        [[ $? = 0 ]] && __logr "Installed $pkg" || __logr "Warning: Failed to installed $pkg"
      done
    fi
  elif cmd_exists dnf; then
    if cmd_exists pkmgr; then
      for pkg in cairo-devel xcb-util-devel libxcb-devel xcb-proto xcb-util-image-devel xcb-util-wm-devel; do
        pkmgr silent install "$pkg" &>/dev/null
        [[ $? = 0 ]] && __logr "Installed $pkg" || __logr "Warning: Failed to installed $pkg"
      done
    fi
  elif cmd_exists yum; then
    if cmd_exists pkmgr; then
      for pkg in cairo-devel xcb-util-devel libxcb-devel xcb-proto xcb-util-image-devel xcb-util-wm-devel; do
        pkmgr silent install "$pkg" &>/dev/null
        [[ $? = 0 ]] && __logr "Installed $pkg" || __logr "Warning: Failed to installed $pkg"
      done
    fi
  fi
  __printf_color "$YELLOW" "Done trying to install packages"
  return
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__init() {
  if [[ -z "$BUILD_FORCE" ]] && [[ -f "$(builtin type -P "$BUILD_NAME" 2>/dev/null)" ]]; then
    __printf_color "$RED" "$BUILD_NAME is already installed at:" 1>&2
    __printf_color "$GREEN" "$(builtin type -P "$BUILD_NAME" 2>/dev/null)"
    __printf_color "$YELLOW" "run with --force to rebuild" 1>&2
    exitCode="0"
    exit 0
  fi
  __printf_color "$PURPLE" "Initializing build script for $BUILD_NAME"
  __printf_color "$CYAN" "Saving all output to $BUILD_LOG_FILE"
  sleep 3
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__logr() { echo -e "$*" | tee -a "$BUILD_LOG_FILE" &>/dev/null; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__printf_color() { echo -e "\t\t${1:-}${2:-}${NC}"; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__help() {
  [[ -z "$ARRAY" ]] || local array="[${ARRAY//,/ }]"
  [[ -z "$LONGOPTS" ]] || local opts="[--${LONGOPTS//,/ --}]"
  __printf_color "$BLUE" "Usage: $APPNAME $opts $array"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check for needed applications
type -P bash &>/dev/null || { __printf_color "$RED" "Missing: bash" && exit 1; }
type -P make &>/dev/null || { __printf_color "$RED" "Missing: make" && exit 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set variables
exitCode="0"
NC="$(tput sgr0 2>/dev/null)"
RESET="$(tput sgr0 2>/dev/null)"
BLACK="\033[0;30m"
RED="\033[0;31m"
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
# Application Folders

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Show warn message if variables are missing

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set options
SETARGS="$*"
SHORTOPTS=""
LONGOPTS="version,help,raw,force"
ARRAY=""
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Setup application options
setopts=$(getopt -o "$SHORTOPTS" --long "$LONGOPTS" -a -n "$APPNAME" -- "$@" 2>/dev/null)
eval set -- "${setopts[@]}" 2>/dev/null
while :; do
  case $1 in
  --help)
    shift 1
    __help
    exit
    ;;
  --version)
    shift 1
    __printf_color "$YELLOW" "$APPNAME Version: $VERSION\n"
    exit
    ;;
  --raw)
    shift 1
    __printf_color() { shift 1 && echo -e "$1"; }
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
# Additional variables
BUILD_NAME="jgmenu"
BUILD_SRC_URL="${BUILD_SRC_URL:-https://github.com/johanmalm/jgmenu}"
BUILD_SRC_DIR="${BUILD_SRC_DIR:-$HOME/.local/share/$BUILD_NAME/source}"
BUILD_LOG_FILE="${BUILD_LOG_FILE:-/tmp/${BUILD_NAME}_build.log}"
if command -v "$BUILD_NAME" | grep -q '^/bin' || command -v "$BUILD_NAME" | grep -q '^/usr/bin'; then
  BUILD_DESTDIR="/usr"
else
  BUILD_DESTDIR="${BUILD_DESTDIR:-/usr/local}"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Main application
if [[ -d "$BUILD_SRC_DIR" ]]; then
  if ! builtin cd "$BUILD_SRC_DIR"; then
    __printf_color "$RED" "Failed to cd into $BUILD_SRC_DIR"
    exit 1
  fi
  __init
  __packages
  __run_git
  __make_build
  __check_log
  exitCode=$?
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# check
if [[ -f "$(builtin type -P "$BUILD_NAME" 2>/dev/null)" ]]; then
  __printf_color "$GREEN" "Successfully installed $BUILD_NAME"
  exitCode=0
else
  __printf_color "$RED" "Failed to install $BUILD_NAME"
  exitCode=1
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# End application
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# lets exit with code
exit ${exitCode:-$?}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# end
