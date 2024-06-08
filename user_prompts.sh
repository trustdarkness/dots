#!/bin/bash
#
# Interactive, simple prompts that allow asking a user 
# if its ok to continue.  Slightly modified, but essentially
# as writtin on stackexchange were I found it in 2023. Any
# license concerns should be deferred to the original authors.
# If that's you, and you prefer I remove this code, please
# inform the repo author and I will do so as soon as I am 
# able.
#
# $Id$
# $Date$
# Expected location in production as $MTEBENV/.user_prompts
# based on .globals in this same directory.

# Read a single char from /dev/tty, prompting with "$*"
# Note: pressing enter will return a null string. Perhaps a version terminated with X and then remove it in caller?
# See https://unix.stackexchange.com/a/367880/143394 for dealing with multi-byte, etc.
function get_keypress {
  prompt="${1:-'something something give me a char'}"
  local IFS=
  >/dev/tty printf '%s' "${prompt}"
  [[ $ZSH_VERSION ]] && read -rk1  # Use -u0 to read from STDIN
  # See https://unix.stackexchange.com/q/383197/143394 regarding '\n' -> ''
  [[ $BASH_VERSION ]] && </dev/tty read -rn1
  printf '%s' "$REPLY"
}
export -f get_keypress

# Get a y/n from the user, return yes=0, no=1 enter=$2
# Prompt using $1.
# If set, return $2 on pressing enter, useful for cancel or defualting
function get_yes_keypress {
  prompt="${1:-'Will it be y or n?'}"
  local enter_return=$2
  # [[ ! $prompt ]] && prompt="[y/n]? "
  while REPLY=$(get_keypress "$prompt"); do
    [[ $REPLY ]] && printf '\n' # $REPLY blank if user presses enter
    case "$REPLY" in
      Y|y)  return 0;;
      N|n)  return 1;;
      '')   [[ $enter_return ]] && return $enter_return
    esac
  done
}
export -f get_yes_keypress

# Prompt to confirm, defaulting to YES on <enter>
function confirm_yes {
  prompt="${1:-'Will it be y or n?'} [Y/n]? "
  return $(get_yes_keypress "$prompt" 0)
}
export -f confirm_yes

function confirm_no {
  local prompt="${*:-Are you sure} [Y/n]? "
  get_yes_keypress "$prompt" 1
}
export -f confirm_no

function get_timed_keypress {
  local IFS=
  >/dev/tty printf '%s' "$*"
  [[ $ZSH_VERSION ]] && read -rk1  # Use -u0 to read from STDIN
  # See https://unix.stackexchange.com/q/383197/143394 regarding '\n' -> ''
  [[ $BASH_VERSION ]] && </dev/tty read -t7
  printf '%s' "$REPLY"
}

function get_timed_yes {
  local prompt="${1:-Are you sure}"
  local enter_return=$2
  # [[ ! $prompt ]] && prompt="[y/n]? "
  while REPLY=$(get_timed_keypress "$prompt"); do
    [[ $REPLY ]] && printf '\n' # $REPLY blank if user presses enter
    case "$REPLY" in
      Y|y)  return 0;;
      N|n)  return 255;;
      '')   [[ $enter_return ]] && return "$enter_return"
    esac
  done
}

function timed_confirm_yes {
  local prompt="${*:-Are you sure} [Y/n]? "
  get_timed_yes "$prompt" 0
}

function timed_confirm_no {
  local prompt="${*:-Are you sure} [Y/n]? "
  get_timed_yes "$prompt" 1
}