#!/bin/bash
#
# Helper functions to start programs after launching a 
# windowing server and window manager.
# Copyright (C) 2024 Michael Thompson
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA

#####################################################
# Search ps for the given search string.  
#  Note: we use px if its available, as its output is
#        a bit more stable from a search perspective
# Args: A search string (username, PID, process name)
# Prints findings to the console. No explicit return.
#####################################################
function psearch() {
  ppx=$(type -p px)
  if [ $? -eq 0 ]; then
    px $@ 2> /dev/null
  else
    ps awux 2> /dev/null |grep $@
  fi 
}

#####################################################
# Start a user provided list of not-currently-running
# processes, printing which were detected as running 
# to stdout and silently starting the others in the
# background.  Provided processes should not require
# args themselves.  See below for that functionality,
# Globals: $PS should be an executable reference to 
#           a filterable process monitor such that
#           arguments provided to it are process names
#           that it uses as an include filter.  
#           $PS is not modified here.
# Arguments: a list of processes to start, no args
######################################################
function start_if_not_list() {
  running="$(psearch $(whoami))"
  for i in $@; do 
    if ! string_contains "$i" "$running"; then
      $i &
    else
      echo "$i already running."
    fi
  done
}

#####################################################
# Start a user provided list of not-currently-running
# processes, printing which were detected as running 
# to stdout and silently starting the others in the
# background.  Provided processes may have their own
# arguments which will be passed along to run.
# Globals: $PS should be an executable reference to 
#           a filterable process monitor such that
#           arguments provided to it are process names
#           that it uses as an include filter.  
#           $PS is not modified here.
# Arguments: a list of processes to start, with any
# necessary arguments, provided in the same format
# and order expected on the shell
######################################################
function start_if_not_args() { 
  running="$(psearch $(whoami))"
  if ! string_contains "$1" "$running"; then
    $@ &
  else
    echo "$1 already running."
  fi
}
