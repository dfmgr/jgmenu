#!/usr/bin/env bash

SCRIPTNAME="$(basename $0)"
SCRIPTDIR="$(dirname "${BASH_SOURCE[0]}")"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# @Author      : Jason
# @Contact     : casjaysdev@casjay.net
# @File        : build
# @Created     : Mon, Dec 31, 2019, 00:00 EST
# @License     : WTFPL
# @Copyright   : Copyright (c) CasjaysDev
# @Description : jgmenu build script
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Set functions

if [ -f /usr/local/share/CasjaysDev/scripts/functions/app-installer.bash ]; then
  . /usr/local/share/CasjaysDev/scripts/functions/app-installer.bash
else
  curl -LSs https://github.com/dfmgr/installer/raw/master/functions/app-installer.bash -o /tmp/app-installer.bash || exit 1
  . /tmp/app-installer.bash
  rm_rf /tmp/app-installer.bash
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

printf_red "\t\tRequesting root privileges\n"
sudoask

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if ! cmd_exists jgmenu; then
  if [ -d "$HOME/.local/tmp/jgmenu" ]; then
    cd "$HOME/.local/tmp/jgmenu"
    git pull
  else
    git_clone https://github.com/johanmalm/jgmenu "$HOME/.local/tmp/jgmenu"
    cd "$HOME/.local/tmp/jgmenu"
  fi
  ./configure --prefix=/usr/local --with-lx --with-pmenu
  make
  sudo make install
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if cmd_exists jgmenu; then
  printf_green "\t\tjgmenu has been installed\n"
else
  printf_red "\t\tjgmenu has failed to build\n"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# exit
if [ ! -z "$EXIT" ]; then exit "$EXIT"; fi

# end
#/* vim set expandtab ts=4 noai
