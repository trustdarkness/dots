#!/bin/bash
if ! declare -F is_function; then
  is_function() {
    ( declare -F "${1:-}" > /dev/null 2>&1 && return 0 ) || return 1
  }
fi

source $HOME/.bashrc

# Just in case something goes wrong and we haven't leaded D above
if [ -z "$D" ]; then
  if is_function "detect_d"; then detect_d; else  
    if [[ "${BASH_SOURCE[0]}" == */* ]]; then 
      if [ -f "$(dirname \"${BASH_SOURCE[0]}\")/util.sh" ]; then 
        D="$(dirname \"${BASH_SOURCE[0]}\")"
      fi
    fi
    if [ -z "$D" ]; then if "$(pwd)/util.sh"; then D="$(pwd)"; fi; fi
  fi
  if [ -z "$D" ]; then 
    echo "couldnt find the dots repo, please set D=path"; 
    return 1
  fi
fi

if [[ $(uname) == "Darwin" ]]; then 
  source "$D/macprofile.sh"
elif [[ "$DESKTOP_SESSION" == "plasma" ]]; then 
  source "$D/kutil.sh"
fi
