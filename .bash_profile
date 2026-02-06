#!/usr/bin/env bash
# We assume .bash_profile is sourced once per "session" where session
# is somewhat loosely defined, but basically means an X (or presumably
# wayland) session on Linux, but on MacOS, every shell is a login shell,
# but we can establish a similar "session" concept on Mac using launchctl
# as our global space for MacOS tasks.  For bash globals, we either
# abuse launchctl vars (in macprofile.sh) or live with them being
# reset with each terminal launch
declare -F detect_d > /dev/null 2>&1 || detect_d() {
  if [ -n "${D}" ]; then
    echo "D set to ${D}.  detect_d returning 0."
    return 0
  fi
  # -z || here for first run conditions
  if [ -z $DEBUG ] || $DEBUG; then
    >&2 printf ".bash_profile sourced from ${BASH_SOURCE[@]}\n"
  fi
  if [[ "${BASH_SOURCE[0]}" == ".bash_profile" ]]; then
    if [ -f "$(pwd)/util.sh" ]; then
      D="$(pwd)"
      export D
      return 0
    fi
  else
    : # REALBASHRC=$(readlink ${BASH_SOURCE[0]})
    # D=$(dirname $REALBASHRC)
  fi
  if [ -z "${D}" ]; then
    >&2 printf "no luck finding D, please set"
    return 1
  fi
}

if [ -z "${D}" ]; then
  if [ -d "$HOME/src/github/dots" ]; then
    export D="$HOME/src/github/dots"
  else
    detect_d
  fi
fi

if [ -z "$BASH_PROFILE_SOURCED" ]; then
  BASH_PROFILE_SOURCED=1
  export BASH_PROFILE_SOURCED
else
  ((BASH_PROFILE_SOURCED++))
fi

VERSION_REGEX='[0-9]+\.?[0-9]*\.?[0-9]*.*'

# this needs tests
function version_lt() {
  major() {
    full="${1:-}"
    echo "$full" | cut -d "." -f 1
  }
  minor() {
    full="${1:-}"
    echo "$full" | cut -d "." -f 2
  }
  sub() {
    full="${1:-}"
    # this is a but hacky but should capture things like
    # 57(1)-release such that it's less than 57(2)-release
    echo "$full" | cut -d "." -f 3 | sed -e 's/[^0-9]//g'
  }
  q="${1:-}"
  compare_to="${2:-}" # assume version string int.int.int<othertext>
  if [[ "$q" =~ $VERSION_REGEX ]] && [[ "$compare_to" =~ $VERSION_REGEX ]]; then
    major_q=$(major "$q")
    major_compare_to=$(major "$compare_to")
    if [ -n "$major_q" ] && [ -n "$major_compare_to" ]; then
      if [  $major_q -lt $major_compare_to ]; then
        return 0
      elif [ $major_q -eq $major_compare_to ]; then
        minor_q=$(minor "$q")
        minor_compare_to=$(minor "$compare_to")
        if [ -n "$minor_q" ] && [ -n "$minor_compare_to" ]; then
          if [ $minor_q -lt $minor_compare_to ]; then
            return 0
          elif [ $minor_q -eq $minor_compare_to ]; then
            sub_q=$(sub "$q")
            sub_compare_to=$(sub "$compare_to")
            if [ -n "$sub_q" ] && [ -n "$sub_compare_to" ]; then
              if [ $sub_q -lt $sub_compare_to ]; then
                return 0
              fi
            fi
          fi
        fi
      fi
    fi
  fi
  return 1
}

shopt -s expand_aliases

# colors for logleveled output to stderr
# TODO (low): dedup from util / log
TS=$(tput setaf 3) # yellow
DBG=$(tput setaf 6) # cyan
INF=$(tput setaf 2) # green
WRN=$(tput setaf 208) # orange
ERR=$(tput setaf 1) # red
STAT=$(tput setaf 165) # pink
VAR=$(tput setaf 170) # lightpink
CMD=$(tput setaf 36) # aqua
MSG=$(tput setaf 231) # barely yellow
RST=$(tput sgr0) # reset

declare -F is_function > /dev/null 2>&1 || is_function() {
  ( declare -F "${1:-}" > /dev/null 2>&1 && return 0 ) || return 1
}
export -f is_function

# until we sync everything up
if [ -n "$DEBUG" ] && $DEBUG; then LEVEL=DEBUG; fi

# preferred format strings for date for storing on the filesystem
FSDATEFMT="%Y%m%d" # our preferred date fmt for files/folders
printf -v FSTSFMT '%s_%%H%%M%%S' "$FSDATEFMT" # our preferred ts fmt for files/folders

function fsdate() {
  date +"${FSDATEFMT}"
}

function fsts_to_fsdate() {
  if is_mac; then
    date -d -f "$FSTSFMT" "${1:-}" "$FSDATEFMT"
  else
    date -d "$(_fsts_gnu_readable "${1:-}")"  +"$FSDATEFMT"
  fi
}

function fsts() {
  date +"${FSTSFMT}"
}

# for sub-second accuracy
function fstsss() {
  date +"${FSTSFMT}%T.%3N"
}


# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
unset HISTFILESIZE
HISTSIZE=1000000

source "${D}/.bashrc"

if [[ $(uname) == "Darwin" ]] then
  # since .bash_profile doesn't work the same on MacOS as other *nix's
  # macprofile is for run-once-per-session things.  It sets an env var
  # via launchctl called MACPROFILED, so we can skip sourcing it in
  # subsequent sourcings of .bash_profile
  MACPROFILED=$(launchctl getenv MACPROFILED)
  if [ -z "$MACPROFILED" ]; then
    source "${D}/macprofile.sh"
  fi
else # assume linux
  # if PL_SHELL is true, powerline will be invoked by default
  # export PL_SHELL="true"

  d=$(date +"%Y%m%d")
  mkdir -p "$HOME/.local/share/bash_histories/$d"
  cp -r "$HOME/.bash_history"* "$HOME/.local/share/bash_histories/$d"

  if [[ "$DESKTOP_SESSION" == "plasma" ]]; then
    source "${D}/kutil.sh"
  fi
fi

c="$BASH_COMMAND"
if [[ "$c" == *'-c'* ]] && [[ "$c" == *"sudo"* ]]; then
  >&2 printf "$BASH_SOURCE $c"
  source "${D}/util.sh"
fi

_bash_profile_fs() {
  function_finder -f "${D}/.bash_profile"
}
