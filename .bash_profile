#!/bin/bash
export BACKUP="egdod/Backup"
export TARGET=vulcan
export VIDLIB=mmzzkk
export PHOTOLIB=fodder
export MUSICLIB="/mmzzkk/Music"
export MBKS="/egdod/Backup/xMusic/"
export MARCH="/egdod/Backup/xMusic/Music_Archived"
export LH="$HOME/src/github/library-helpers"

source $HOME/.bashrc
source $LH/util.sh

# use px if available
PS=$(which px)
if ! [ -n "$PS" ]; then
  PS="ps awux |grep"
fi

function start_if_not_list() {
  running="$($PS `whoami`)"
  for i in $@; do 
    if ! stringContains "$i" "$running"; then
      $i &
    else
      echo "$i already running."
    fi
  done
}
export -f start_if_not_list

function start_if_not_args() { 
  running="$($PS `whoami`)"
  if ! stringContains "$1" "$running"; then
    $@ &
  else
    echo "$1 already running."
  fi
}
export -f start_if_not_args
