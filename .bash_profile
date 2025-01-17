#!/bin/bash
if ! declare -F is_function; then
  is_function() {
    ( declare -F "${1:-}" > /dev/null 2>&1 && return 0 ) || return 1
  }
fi
export -f is_function

source $HOME/.bashrc

if [[ $(uname) == "Darwin" ]]; then
  # since .bash_profile doesn't work the same on MacOS as other *nix's
  # macprofile is for run-once-per-session things.  It sets an env var
  # via launchctl called MACPROFILED, so we can skip sourcing it in
  # subsequent sourcings of .bash_profile
  MACPROFILED=$(launchctl getenv MACPROFILED)
  if [ -z "$MACPROFILED" ]; then
    source "$D/macprofile.sh"
  fi
else
  d=$(date +"%Y%m%d")
  mkdir -p "$HOME/.local/share/bash_histories/$d"
  cp -r "$HOME/.bash_history*" "$HOME/.local/share/bash_histories/$d"
fi
if [[ "$DESKTOP_SESSION" == "plasma" ]]; then
  source "$D/kutil.sh"
fi

_bash_profile_fs() {
  function_finder -f "$D/.bash_profile"
}
