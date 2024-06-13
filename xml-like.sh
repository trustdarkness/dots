#!/usr/bin/env bash
# the following two functions are the start of a currently only semi-usable
# parser for some generic xml-like data based largely on
# https://stackoverflow.com/questions/893585/how-to-parse-xml-in-bash
# and ultimately intended to make adding UI elements to qml frontend
# specs (impulse was to bootstrap my desired config for konsole on a fresh)
# install... the config in question is found at 
# $HOME/.local/share/kxmlgui5/konsole/konsoleui.rc
function starml_read_dom () {
  local IFS=\>
  read -d \< ENTITY CONTENT
  local RET=$?
  TAG_NAME=${ENTITY%% *}
  ATTRIBUTES=${ENTITY#* }
  return $RET
}

function xmllike() {
  set -x
  file="${1:-}"
  lfunction="${2:-get_tags}"

  get_tags() {
    local name="${1:-}"
    if [ -n "${name}" ]; then
      if [[ $TAG_NAME == "${name}" ]]; then
        se "exposing ${ATTRIBUTES} of tag ${name}" 
        eval local ${ATTRIBUTES}
      fi
    fi
    if ${all}; then 
      echo ${TAG_NAME}
    fi
  }
  while starml_read_dom; do ${lfunction}; done < "${file}"
 set +x
}