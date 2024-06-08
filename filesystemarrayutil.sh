#!/bin.bash
# for portability we need the above, for the mac os, we need the below
if [ -f "/usr/local/bin/bash" ]; then 
  /usr/local/bin/bash
fi

# you can't pass arrays around as args in bash, but if you do 
# a global declare you can copy it out of the env
declare -a dirarray
function finddir_array() {
  set=false
  depth=1
  while [ $# -gt 0 ]; do
    case "${1:-}" in
      "-d"|"--maxdepth")
        depth="${2:-${depth}}"
        shift 
        shift
        ;;
      "-s"|"--set")
        set=true
        shift
        ;;
      "-h"|"-?"|"--help")
        help
        return 0
        ;;
      *)
        dir="${1:-}"
        shift
        ;;
    esac
  done
  help() {
    se "Creates a bash array named dirarray and populates it with"
    se "subdirectories of the directory provided as an arg."
    se ""
    se "Options:"
    se "  -d|--maxdepth directory maxdepth to pass to find "
    se "                (default 1, for all, pass -1)"
    se "  -s|--set      populate dirarray with only unique values"
    se "                defaults to false, for some reason"
    se "  -h|-?|--help  prints this text"
  }
  dirarray=()
  findargs=( "${dir}" )
  if [ -d "${dir}" ]; then
    if ! [[ "${depth}" == "-1"  ]]; then 
      findargs+=( "-maxdepth" "${depth}" )
    fi
    if "${set}"; then
      while IFS= read -r -d $'\0'; do
        dirarray+=("$REPLY") # REPLY is the default
      done < <(find "${findargs[@]}" -print0 2> /dev/null |sort -uz) 
    else
      while IFS= read -r -d $'\0'; do
        dirarray+=("$REPLY") # REPLY is the default
      done < <(find "${findargs[@]}" -print0 2> /dev/null)
    fi
  else
    >&2 printf "please provide an existing directory as an arg"
  fi
}



declare -ga findarray
function find_array() {
  set=false
  depth=1
  local POSITIONAL_ARGS=()
  while [ $# -gt 0 ]; do
    case "${1:-}" in
      "-d"|"--maxdepth")
        depth="${2:-}"
        shift 
        shift
        ;;
      "-s"|"--set")
        set=true
        shift
        ;;
      "-h"|"-?"|"--help")
        help
        return 0
        ;;
      *)
        POSITIONAL_ARGS+=("${1-}") 
        shift 
        ;;
    esac
  done
  set -- ${POSITIONAL_ARGS[@]+"${POSITIONAL_ARGS[@]}"}
  findargs=( "${POSITIONAL_ARGS[@]}" )
  help() {
    se "Creates a bash array named findarray and populates it with"
    se "the results of the find command with the provided args to"
    se "this function, adding -print0 2> /dev/null for you and"
    se "| sort -uz if called with -s."
    se ""
    se 'Recommended that you copy the populated array ${findarray[@]}'
    se "into the local namespace immediately upon return."
    se ""
    se "Options:"
    se "  -s|--set      populate dirarray with only unique values"
    se "                defaults to false, for some reason"
    se "  -h|-?|--help  prints this text"
  }
  findarray=()
  if ! [[ "${depth}" == "-1"  ]]; then 
    findargs+=( "-maxdepth" "${depth}" )
  fi
  if "${set}"; then
    while IFS= read -r -d $'\0'; do
      findarray+=("$REPLY") # REPLY is the default
    done < <(find "${findargs[@]}" -print0 2> /dev/null |sort -uz) 
  else
    while IFS= read -r -d $'\0'; do
      findarray+=("$REPLY") # REPLY is the default
    done < <(find "${findargs[@]}" -print0 2> /dev/null)
  fi
}

# though you can't pass arrays around as arguments (See above)
# you can pass a named reference and address it on the other side
function components_to_path() {
  name=$1[@]
  path_components=("${!name}")
  IFS='/' read -r -a path_components <<< "${path_to_plist}"
  printf -v path "/%s" "${path_components[@]%/}"
  printf "%s" "${path#/}"
}

# Takes the name of an array (not the array itself) as arg1
# and echos a stringified version back to the console, optionally 
# separating elements with Arg2 and replacing spaces with Arg3
function stringify() {
  name=$1[@]
  element_separator="${2:-' '}"
  space_replacer="${3:=' '}"
  array=("${!name}")
  if [ -n "${space_replacer}" ]; then 
    newarray=()
    for el in "${array[@]}"; do 
      printf -v sedstring 's/" "/%s/' "${space_replacer}"
      newarray+=( $(echo "${el}"|sed "${sedstring}") )
    done
    array=( "${newarray[@]}" )
  fi
  
  echo "${array[*]// /${separator}}"
}

most_recent_in_dir() {
  local dir="${1:-.}"
  # where field is any 1 indexed numbered column returned by ls -l
  # splitting on spaces (no special date handling), defaults to filename
  # addressed in awk as NF (or 9 if you prefer)
  explainer="arg 2 should be an int in the range 1-9\n"
  explainer+="(numbered column returned by ls -l, space separated)"
  local field="${2:-9}"
  if ! [[ $(seq 1 9) == *${field}* ]]; then 
    se "${explainer}"
  fi
  printf -v awkprint '{print$%s}' ${field}
  most_recent=$(ls -Art "${dir}"| tail -n 1 )
  field=$(ls -l "${dir}/${most_recent}" |awk "${awkprint}")
  echo "${field}"
}

most_recent_char_replaced_separated() {
  # find gives you back \0 entries by default, which would be fine, and
  # non-printable characters are probably better for a lot of reasons, but
  # not for debugging.  We default to these, but you may set whatever you
  # like with args 2 and 3
  local default_filename_separator="|"
  local default_space_replaver="+"
  local char_replaced_separated_files="${1:-}"
  local filename_separator="${2:-$default_filename_separator}"
  local space_replacer="${3:-$default_space_replacer}"
  readarray -d"$filename_separator" files < <(echo "${char_replaced_separated_files}")
  # https://stackoverflow.com/questions/5885934/bash-function-to-find-newest-file-matching-pattern
  for file in "${files}"; do 
    file="$(echo ${file}|tr "$space_replacer" ' '|sed 's/|//g')"
    stat -f "%m%t%N" "${file}"
  done | sort -rn | head -1 | cut -f2-
}