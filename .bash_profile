#!/bin/bash
if ! declare -F is_function; then
  is_function() {
    ( declare -F "${1:-}" > /dev/null 2>&1 && return 0 ) || return 1
  }
fi
export -f is_function

source $HOME/.bashrc

if [[ $(uname) == "Darwin" ]] then 
  # since .bash_profile doesn't work the same on MacOS as other *nix's
  # macprofile is for run-once-per-session things.  It sets an env var
  # via launchctl called MACPROFILED, so we can skip sourcing it in 
  # subsequent sourcings of .bash_profile
  MACPROFILED=$(launchctl getenv MACPROFILED)
  if [ -z "$MACPROFILED" ]; then
    source "$D/macprofile.sh"
  fi
fi