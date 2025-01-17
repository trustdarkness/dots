#!/usr/bin/env bash

# Appends Arg1 to the shell's PATH and exports
function path_append() {
  to_add="${1:-}"
  if [ -d "${to_add}" ]; then
    if ! [[ "${PATH}" == *"${to_add}"* ]]; then
      export PATH="${PATH}:${to_add}"
    fi
  fi
}
export -f path_append

# Prepends Arg1 to the shell's PATH and exports
function path_prepend() {
  to_add="${1:-}"
  if [ -d "${to_add}" ]; then
    if ! [[ "${PATH}" == *"${to_add}"* ]]; then
      export PATH="${to_add}:${PATH}"
    fi
  fi
}
export -f path_prepend

path_additions=(
  "$HOME/bin"
  "$HOME/.local/bin"
  "/sbin"
  "/usr/sbin"
  "$HOME/Applications"
  "/opt/bin"
)

_setup_path() {
  for addition in "${path_additions[@]}"; do
    if [[ "$PATH" != *"$addition"* ]]; then
      path_prepend "$addition"
    fi
  done
}

_pathlib_fs() {
  function_finder "$D/pathlib.sh"
}