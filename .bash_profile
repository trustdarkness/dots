#!/usr/bin/env bash
# We assume .bash_profile is sourced once per "session" where session
# is somewhat loosely defined, but basically means an X (or presumably
# wayland) session on Linux, but on MacOS, every shell is a login shell,
# but we can establish a similar "session" concept on Mac using launchctl
# as our global space for MacOS tasks.  For bash globals, we either
# abuse launchctl vars (in macprofile.sh) or live with them being
# reset with each terminal launch
declare -F detect_d > /dev/null 2>&1 || detect_d() {
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
  if [ -z "$D" ]; then
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

source "$HOME/.bashrc"

if [[ $(uname) == "Darwin" ]] then
  # since .bash_profile doesn't work the same on MacOS as other *nix's
  # macprofile is for run-once-per-session things.  It sets an env var
  # via launchctl called MACPROFILED, so we can skip sourcing it in
  # subsequent sourcings of .bash_profile
  MACPROFILED=$(launchctl getenv MACPROFILED)
  if [ -z "$MACPROFILED" ]; then
    source "$D/macprofile.sh"
  fi
else # assume linux
  # if PL_SHELL is true, powerline will be invoked by default
  # export PL_SHELL="true"

  d=$(date +"%Y%m%d")
  mkdir -p "$HOME/.local/share/bash_histories/$d"
  cp -r "$HOME/.bash_history"* "$HOME/.local/share/bash_histories/$d"

  if [[ "$DESKTOP_SESSION" == "plasma" ]]; then
    source "$D/kutil.sh"
  fi
fi

if [[ "$BASH_COMMAND" == *'-c'* ]] && [[ "$BASH_COMMAND" == *"sudo"* ]]; then
  source util.sh
fi

_bash_profile_fs() {
  function_finder -f "$D/.bash_profile"
}
