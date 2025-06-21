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

ssource() {
  force=false
  # delimiter for csv file (in place of comma):
  local d='|'
  local ts=$(date +%s%N)
  local caller="$(caller)"
  if [[ "${1:-}" == \-f ]]; then
    force=true
    shift
  fi

  if [ -z "$SSOURCED_SESSION" ]; then
    # we need an external identifier available in the shell's env that
    # is unique to this session... there are a few candidates, but no
    # bulletproof cross platform ones.  All this code is already so
    # fragile that hopefully no one else relies on it, but I run
    # all different kinds of machines, so...
    if [ -n "$INVOCATION_ID" ]; then # seems to cover linux
      session_id="$INVOCATION_ID"
    elif [ -n "$TERM_SESSION_ID" ]; then # both iterm and Terminal.app
      session_id="$TERM_SESSION_ID"
    else
      # we can shove our own session id based on the timestamp into
      # the environnment, but this is best effort (as is maintaining
      # session overall, though the stable identifier helps).
      session_id="$(fsts)"
    fi
    if [ -n "$session_id" ]; then
      # if there's an application relevant state or logdir in the env
      # we should use that, but better to use /tmp than to create our
      # own, we want something that the OS will routinely cleanup
      # listed are in reverse priority
      possible_appdirs=( "TMPDIR" "LOGDIR" "STATEDIR" )
      for appdir in "${possible_appdirs[@]}"; do
        local -n envvar="$appdir"
        if [ -n "$envvar" ] && [ -f "$envvar" ]; then
          # if any are available, the last will take the win
          SSOURCED_SESSION="${envvar}/sourced-${session_id}"
        fi
      done
      # if we didn't find anything, use /tmp
      if ! [ -z "SSOURCED_SESSION" ]; then
        SSOURCED_SESSION="/tmp/sourced-${TERM_SESSION_ID}"
      fi
    fi
  fi
  if [ -f "${SSOURCED_SESSION}" ]; then
    if grep -q "${1:-}" "${SSOURCED_SESSION}" > /dev/null; then
      if "$force"; then
        builtin source "${1:-}"
        return $?
      else
        >&2 printf "${1:-} already sourced\n"
        return 0
      fi
    fi
  fi
  # SSOURCED_SESSION should exist no matter what now, but
  if [ -n "${SSOURCED_SESSION}" ]; then
    builtin source "${1:-}"
    els=("$ts" "$caller" "${1:-}")
    printf -v line "%s${d}" "${els[@]}"
    # drop the trailing delimiter
    echo "${line:0:-1}" >> "${SSOURCED_SESSION}"
    return $?
  fi
  >&2 printf "source session not established.  calling builtin source ${1:-}.\n"
  builtin source "${1:-}"
  return $?
}

ssource "${D}/.bashrc"

if [[ $(uname) == "Darwin" ]] then
  # since .bash_profile doesn't work the same on MacOS as other *nix's
  # macprofile is for run-once-per-session things.  It sets an env var
  # via launchctl called MACPROFILED, so we can skip sourcing it in
  # subsequent sourcings of .bash_profile
  MACPROFILED=$(launchctl getenv MACPROFILED)
  if [ -z "$MACPROFILED" ]; then
    ssource "${D}/macprofile.sh"
  fi
else # assume linux
  # if PL_SHELL is true, powerline will be invoked by default
  # export PL_SHELL="true"

  d=$(date +"%Y%m%d")
  mkdir -p "$HOME/.local/share/bash_histories/$d"
  cp -r "$HOME/.bash_history"* "$HOME/.local/share/bash_histories/$d"

  if [[ "$DESKTOP_SESSION" == "plasma" ]]; then
    ssource "${D}/kutil.sh"
  fi
fi

c="$BASH_COMMAND"
if [[ "$c" == *'-c'* ]] && [[ "$c" == *"sudo"* ]]; then
  >&2 printf "$BASH_SOURCE $c"
  ssource "${D}/util.sh"
fi

_bash_profile_fs() {
  function_finder -f "${D}/.bash_profile"
}
