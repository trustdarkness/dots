#!/usr/bin/env bash

function superblock_zero() {
  if ! declare -F "confirm_yes" > /dev/null 2>&1; then
    source "$D/user_prompts.sh"
  fi
  mdadm_zero_string="%s mdadm zero superblocks on"
  dd_zero_string="%s dd clear MBR on"
  failures=0
  word=${1}
  declare -ga disks
  disks=()
  for (( i=0; i<${#word}; i++ )); do
    char=${word:$i:1}
    disk="/dev/sd${char}"
    stat "$disk"
    ((failures+=$?))
    disks+=( "$disk" )
    mdadm_zero_string+=" %s"
    dd_zero_string+=" %s"
  done
  if gt $failures 0; then
    echo "can't find disks for your input."
    return $failures
  fi
  if [[ ${1:-} == "-y" ]]; then
    command="echo"
    preamble=""
  else
    command="confirm_yes"
    preamble="(confirm)"
  fi
  mdadm_zero_sb() {
    printf -v string "$mdadm_zero_string" "$preamble" "${disks[@]}"
    $command "$string"
    echo
    if [ $? -eq 0 ]; then
      sudo mdadm --zero-superblock "${disks[@]}"
      if [ $? -gt 0 ]; then
        echo "mdadm exited status $?"
        return 1
      fi
    fi
  }
  dd_zero_mbr() {
    printf -v string "$dd_zero_string" "$preamble" "${disks[@]}"
    $command "$string"
    echo
    if [ $? -eq 0 ]; then
      for disk in "${disks[@]}"; do
        echo "clearing MBR on $disk"
        sudo dd if=/dev/zero of=$disk bs=512 count=1
      done
    fi
  }
  dd_zero_mbr
  mdadm_zero_sb
}

# returns 0 if $1 exists in the array referenced by the name in $2
function in_array() {
  needle="${1:-}"
  haystack_name=$2[@]
  haystack=("${!haystack_name}")
  if [[ "${haystack[*]}" == *"$needle"* ]]; then
    return 0
  fi
  return 1
}

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


# Assume all arguments (count unknown) are path fragments that may be a single
# word or phrase (which we'll treat as atomic, as though its an actual space in
# the file or folder name).  Separators are "/" and only "/".  Value is returned
# as a single quoted path string.
# TODO: add options to specify separator
#       add flag for escaped instead of quoted return
function assemble_bash_safe_path() {
  components=()
  for arg in "$@"; do
    IFS='/' read -r -a components <<< "${arg}"
  done
  printf "'/%s'" "${components[@]%/}"
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

# https://serverfault.com/questions/348482/how-to-remove-invalid-characters-from-filenames
function string_to_safe_filename() {
  echo "${1:-}" | sed -e 's/[^A-Za-z0-9._-]/_/g'
  return 0
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

function quoted_stringify() {
  name=$1[@]
  array=("${!name}")
  out=""
  for el in "${array[@]}"; do
    printf -v out '%s "%s"' "$out" "$el"
  done
  echo "$out"
  return 0
}

# find the most recent file in dir given by $1 that matches
# search term $2 (optional)
function most_recent() {
  local dir="${1:-.}"
  local sterm="${2:-}"
  local files
  if [ -n "$sterm" ]; then
    files="$(find ${dir} -name "*$sterm*" -maxdepth 1 -mindepth 1 -print0 2> /dev/null|tr '\0' '|'|tr ' ' '+')"
  else
    files="$(find ${dir} -maxdepth 1 -mindepth 1 -print0 2> /dev/null|tr '\0' '|'|tr ' ' '+')"
  fi
  #echo "$files"
  local most_recent_crash=$(most_recent "${files}")
  # find gives you back \0 entries by default, which would be fine, and
  # non-printable characters are probably better for a lot of reasons, but
  # not for debugging.  We default to these, but you may set whatever you
  # like with args 2 and 3
  local default_filename_separator="|"
  local default_space_replacer="+"
  local char_replaced_separated_files=("${files[@]}")
  local filename_separator="|"
  local space_replacer="+"
  readarray -d"$filename_separator" files < <(echo "${char_replaced_separated_files}")

  # https://stackoverflow.com/questions/5885934/bash-function-to-find-newest-file-matching-pattern
  for messyfile in "${files[@]}"; do
    file="$(echo ${messyfile}|tr "${space_replacer}" ' '|sed "s/${filename_separator}//g")"
    if [ -n "${file}" ]; then
      stat -f "%m%t%N" "${file}"
    fi
  done | sort -rn | head -1 | cut -f2-
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
  most_recent=$(ls -Alrt "${dir}"| tail -n 1 |awk "${awkprint}")
  echo "${most_recent}"
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

function array_to_set() {
  local -n to_sort="${1:-}"
  #to_sort=("${!name}")
  SORTED=()
  if gt "${#to_sort[@]}" 0; then
    readarray -t SORTED < <(for item in "${to_sort[@]}"; do
      { [ -n "$item" ] && printf '%s\0' "$item"; } || continue
    done | sort -z|xargs -0n1|sort -u)
  fi
  to_sort=("${SORTED[@]}")
}

################################ Friendly note:
# the following functions were written assuming you can pass arrays around
# to functions in bash, which, SURPRISE! you can't.  You can pass by reference
# and when I have time or the need for one of these silly things arises, I will
# rewrite them to do so (and, hopefully, work like they say they do)

# https://unix.stackexchange.com/questions/104837/intersection-of-two-arrays-in-bash#104848
function array_intersection() {
  A="${1:-}"
  B="${2:-}"
  if gt ${#A[@]} 0; then
    return 1
  fi
  if gt ${#B[@]} 0; then
    return 1
  fi
  INTERSECTION=($(comm -12 <(printf '%s\n' "${A[@]}" | LC_ALL=C sort) <(printf '%s\n' "${B[@]}" | LC_ALL=C sort)))
  echo "${INTERSECTION[@]}"
}

# given a sorted array of files with absolute paths, return an array of just basenames.
# note: function will behave with unsorted arrays, but the goal would be to match back up
# with the paths later, in which case, sorting is ideal and not performed by this function
function strip_paths() {
  A="${1:-}"
  if gt ${#A[@]} 0; then
    return 1
  fi
  STRIPPED=()
  for a in "${A[@]}"; do
    bn=$(basename "${a}")
    STRIPPED+=( "${bn}" )
  done
  echo "${STRIPPED[@]}"
}

# given sorted arrays A and B of plugins with absolute paths, return an array of plugins of
# the same type (vst, vst3 or au) and the same plugin name with the absolute paths
# as originally present in array A
function same_plugin_same_type_diff_location() {
  A="${1:-}"
  B="${2:-}"
  if gt ${#A[@]} 0; then
    return 1
  fi
  if gt ${#B[@]} 0; then
    return 1
  fi
  stip_paths "${A[@]}"
  baseA="${STRIPPED[@]}"
  strip_paths "${B[@}]}"
  baseB="${STRIPPED[@]}"
  array_intersection "${baseA[@]}" "${baseB}"
  SAMESAMEDIFF=()
  for absplugin in "${A[@]}"; do
    for plugin in "${INTERSECTION[@]}"; do
      if [[ "${absplugin}" == "*${plugin}" ]]; then
        SAMESAMEDIFF+=( "${absplugin}" )
      fi
    done
  done
  echo "${SAMESAMEDIFF[@]}"
}

function fix_filenames() {
  find . -type f -print0 | while IFS= read -rd '' f; do
    mv "$f" "${f//$'\n'}"
  done
  find . -type f -print0 | while IFS= read -rd '' f; do
    mv "$f" "${f//[^[:print:]]}"
  done
}

# uses find to determine if the current user has read permissions
# recursively below the provided directory
# returns 0 if readable, return code of can_i_do if not
function can_i_read() {
  if [[ "${1:-}" == \-v ]]; then
    _ci_verbose=true; shift
  fi
  can_i_do "${1:-}" 555 $2
}

# uses find to determine if the current user has write permissions
# recursively below the provided directory
# returns 0 if writeable, return code of can_i_do if not
function can_i_write() {
  if [[ "${1:-}" == \-v ]]; then
    _ci_verbose=true; shift
  fi
  dir="${1:-$(pwd)}"
  if [ -d "$dir" ]; then
    whoowns=$(ls -alh "$dir"|head -n2|tail -n1|awk '{print$3}')
    if [[ "${whoowns}" == "$(whoami)" ]]; then
      can_i_do "$dir" 200
      return $?
    else
      grpowns=$(ls -alh "$dir"|head -n2|tail -n1|awk '{print$4}')
      if [[ "${grpowns}" == "$(whoami)" ]]; then
        can_i_do "$dir" 020
        return $?
      else
        can_i_do "$dir" 002
        return $?
      fi
    fi
  fi
  return 1
}


# uses find to determine if the current user has given permissions
# recursively below the provided directory
#
# Args:
#   -v verbose, show Permission denieds from find
# Positional Args:
#  1 - directory name
#  2 - umask
#  3 - depth - defaults to all
# returns 0 if perms match, 127 if unable to write basedir, 1 otherwise
function can_i_do() {
  if [[ "${1:-}" == \-v ]]; then
    _ci_verbose=true; shift
  fi
  local dir="${1:-}"
  local mask="${2:-}"
  local depth="${3:-all}"
  if [ -d "${dir}" ]; then
    local ts="$(fsts)"
    local tempfile="/tmp/permcheck-${ts}"
    local temppid="/tmp/pid-${ts}"
    local tempfin="/tmp/fin-${ts}"
    (
      echo $$ > "${temppid}"
      printf -v dashmask "\x2D%d" "$mask"
      if is_int "${depth}"; then
        find "${dir}" -depth "${depth}" -perm "$dashmask" > "${tempfile}"  2>&1
      elif [[ "${depth}" == "all" ]]; then
        find "${dir}" -perm "$dashmask" > "${tempfile}"  2>&1
      else
        >&2 printf "couldn't understand your third parameter, which should be "
        >&2 printf "depth, either an int or \"all\""
        return 1
      fi
      echo $? > "${tempfin}"
    )
    while ! test -f "${tempfin}"; do
      sleep 1
      cat "${tempfile}"|grep "Permission denied"
      if [ $? -eq 0 ]; then
        kill $(cat "${temppid}")
        return 127
      fi
    done
    if [ -f "${tempfin}" ]; then
      if tru $_ci_verbose; then
        cat "${tempfile}"|grep "Permission denied"
      fi
      return $(cat "${tempfin}")
    fi
    return 0
  else
    >&2 printf "Please supply a path to check"
  fi
}


function symlink_child_dirs () {
  if [ -n "$CACHE" ]; then
    undo_dir="$CACHE/com.trustdarkness.utilsh"
  else
    err "no \$CACHE in env."
    return 1
  fi
  help() {
    >&2 printf "Specify a target parent directory whose children\n"
    >&2 printf "should be symlinked into the desitination directory:\n"
    >&2 printf "\$ symlink_child_dirs [target] [destination]"
  }
  undo_last_change() {
    undo_file=$(most_recent "$undo_dir")
    while string_contains "undone" "$undo_file"; do
      undo_file=$(most_recent "$undo_dir")
    done
    declare -a to_remove
    for line in $(cat "$undo_file"); do
      if [ -h "$line" ]; then
        to_remove+=( "$line" )
        echo "$line"
      fi
    done
    echo
    if confirm_yes "removing the above symbolic links, OK?"; then
      for link in "${to_remove[@]}"; do
        rm -f "$link"
      done
      mv "$undo_file" "${undo_file}.undone"
      return 0
    else
      echo "exiting with no changes"
      return 0
    fi
  }
  optspec="u?h"
  while getopts "${optspec}" optchar; do
    case "${optchar}" in
      u)
        if undo_last_change; then
          se "undo successfully completed"
          return 0
        else
          se "undo failed with code $?"
          return 1
        fi
        shift
        ;;
      h)
        help
        shift
        ;;
    esac
  done
  # Argument should be a directory who's immediate children
  # are themes such that you want to have each directory
  # at the top level (under the parent) symlinked in a
  # target directory.  Intended for use under ~/.themes
  # but presumably, there are other ways this is useful.
  target="${@:$OPTIND:1}"
  whereto="${@:$OPTIND+1}"

  failures=0
  successes=0
  declare -a failed_targets
  declare -a undos
  if [ -d "$target" ]; then
    if ! is_absolute "$target"; then
      echo "the target directory should be an absolute path"
      return 1
    fi
    if [ -d "$whereto" ]; then
      if find $target ! name '.git' -maxdepth 1 -type d -exec ln -s '{}' $whereto/ \;; then
        undos+=( "$whereto/$target" )
        ((successes++))
      else
        ((failures++))
        failed_targets+=( "$whereto/$target" )
      fi
    fi
  else
    echo "arg1 should be a directory containing children to symlink"
    return 1
  fi
  if gt $successes 0; then
    ts=$(fsts)
    undo_dir="$CACHE/com.trustdarkness.utilsh"
    mkdir -p "$undo_dir"
    undo_file="$undo_dir/${FUNCNAME[0]}.$ts.undo"
    for line in "${undos[@]}"; do
      echo "$line" >> "$undo_file"
    done
    echo "Changes recorded at $undo_file, run ${FUNCNAME[0]} -u to undo"
    echo
  fi
  if gt $failures 0; then
    se "failed to create the following:"
    for failure in "${failed_targets[@]}"; do echo "$failure"; done
  fi
}

samepath() {

  # set -x

  return_e() (
  trap 'e=( \
    [0]="N/A" \
    [1]="Argument one ($one) does not seem to be a valid path" \
    [2]="Argument two ($two) does not seem to be a valid path" \
    [3]="Both paths are mounted from the same device ($onemount), but dont seem to have the same path from their respective mountpoints." \
    [4]="These two paths are mounted from different devices ($one from $onemount; $two from $twomount)" \
    [5]="This code should be unreachable." \
  ) \
  le=$?; [ $le -gt 0 ] && err ${e[$le]}; trap RETURN' RETURN
    # set -x
    one="${1:-}"
    two="${2:-}"
    if ! is_absolute "$one"; then
      one="$(realpath "$one")"
    fi
    if ! is_absolute "$two"; then
      two="$(realpath "$two")"
    fi
    ! [ -e "$one" ] && return 1
    ! [ -e "$two" ] && return 2
    [[ "$one" == "$two" ]] && return 0 # trivial case
    onemount="$(findmnt -n -o SOURCE --target "$one")"
    twomount="$(findmnt -n -o SOURCE --target "$two")"
    if [[ "$onemount" == "$twomount" ]]; then
      readarray -t mounts < <(findmnt -n "$onemount" -o TARGET)
      { [[ "${one/${mounts[0]}/}" == "${two/${mounts[1]}/}" ]] && return 0; } || true
      { [[ "${one/${mounts[1]}/}" == "${two/${mounts[0]}/}" ]] && return 0; } || true
      return 3
    else
      return 4
    fi
    return 5
  )
  return_e $@
}

safe_mount_x() {
  mnt=$1
  uuid=$2
  isLuks=false
  disk="/dev/disk/by-uuid/$uuid"
  if sudo cryptsetup isLuks "$disk"; then isLuks=true; fi
  if isLuks; then mapped="/dev/mapper/luks-$uuid"; fi
  mounted=$(mountpoint $mnt);
  if [ $? -ne 0 ]; then
    if $isLuks; then
      udisksctl unlock -b $disk
      sleep 2
      sudo mount "$mapped" "$mnt"
    else
      sudo mount "$disk" "$mnt"
    fi
  fi
}