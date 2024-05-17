#!env bash
alias vbrc="vim $HOME/.bashrc && source $HOME/.bashrc"
alias brc="vimcat ~/.bashrc"
alias sbrc="source $HOME/.bashrc"
alias pau="ps auwx"
alias paug="ps auwx|grep "
alias paugi="ps awux|grep -i "
alias rst="sudo shutdown -r now"
alias gh="mkdir -p $HOME/src/github && cd $HOME/src/github"
alias gl="mkdir -p $HOME/src/gitlab && cd $HOME/src/gitlab"
alias gc="git clone"
export GH="$HOME/src/github"

source $D/.user_prompts

DEBUG=true

function debug() {
  if ${DEBUG}; then
    se $@
  fi
}

function se() {
  if [ $# -eq 2 ]; then 
    >&2 printf "${1:-}\n" "${@:2:-}"
  else
    >&2 printf "${1:-}\n"
  fi
}

function string_contains() {
  echo "${2:-}"| grep -Eqi "${1:-}" 
  return $?
}
alias stringContains="string_contains"

function shellquote() {
  printf '"%s"\n' "$@"
}

function singlequote() {
  printf "'%s'\n" "$@"
}

function shellescape() {
  printf "%q\n" "$@"
}

function hn () {
  if [ $# -eq 0 ]; then 
    >&2 printf "give me a list of hosts to get ips for"
    return 1;
  fi

  IPR='^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.){3}(25[0-5]|(2[0-4]|1\d|[1-9]|)\d)$'

  # get hosts from ssh config
  for h in $(echo $@| tr " " "\n"); do
    SSHOST="$(grep -A2 $h $HOME/.ssh/config|grep hostname)"
    if [ $? -ne 0 ]; then
      IP="$(echo $SSHOST|grep '$IPR')"
      if [ $? -ne 0 ]; then
        echo "$h: $IP"
      fi
    fi
    if [ -n "$IP" ]; then 
      dig $h
    fi
    IP=""
  done
}

function symlink_child_dirs () {
  # Argument should be a directory who's immediate children
  # are themes such that you want to have each directory  
  # at the top level (under the parent) symlinked in a 
  # target directory.  Intended for use under ~/.themes
  # but presumably, there are other ways this is useful. 
  TARGET=$1
  LNAME=$2

  # give success a silly nonsensical value that the shell would never.
  success=257

  if [ -d "$TARGET" ]; then
    if [ -d "$LNAME" ]; then
      e=$(find $TARGET -maxdepth 1 -type d -exec ln -s '{}' $LNAME/ \;)
      success=$?
    fi
  fi
  if [ $success -eq 257 ]; then
    >&2 printf "Specify a target parent directory whose children\n"
    >&2 printf "should be symlinked into the desitination directory:\n"
    >&2 printf "\$ symlink_child_dirs [target] [destination]"
  fi
}

# thats too long to type though.
alias scd="symlink_child_dirs"

function ghc () {
  if [ $# -eq 0 ]; then
    url="$(xclip -out)"
    if [ $? -eq 0 ]; then
      "No url given in cmd or on clipboard."
      return 1
    fi
  else
    url=$1
  fi
  gh
  gc $url
  
  f=$(echo "$url"|awk -F"/" '{print$NF}')
  if [[ $f == *".git" ]]; then 
    f="${f%.*}"
  fi
  cd $f
}

ssudo () # super sudo
{
  [[ "$(type -t $1)" == "function" ]] &&
    ARGS="$@" && sudo bash -c "$(declare -f $1); $ARGS"
}
alias ssudo="ssudo "

function bash_major_version() {
  echo "${BASH_VERSINFO[0]}"
}
export -f bash_major_version

function bash_minor_version() {
  echo "${BASH_VERSINFO[1]}"
}
export -f bash_minor_version

function bash_version() {
  major=$(bash_major_version)
  minor=$(bash_minor_version)
  echo "${major}.${minor}"
}
export -f bash_version

# stolen from https://stackoverflow.com/questions/8654051/how-can-i-compare-two-floating-point-numbers-in-bash
is_first_floating_number_bigger () {
    number1="$1"
    number2="$2"

    [ ${number1%.*} -eq ${number2%.*} ] && [ ${number1#*.} \> ${number2#*.} ] || [ ${number1%.*} -gt ${number2%.*} ];
    result=$?
    if [ "$result" -eq 0 ]; then result=1; else result=0; fi

    __FUNCTION_RETURN="${result}"
}

# Assume all arguments (count unknown) are path fragments that may be a single
# word or phrase (which we'll treat as atomic, as though its an actual spacew in
# the file or folder name).  Separators are "/" and only "/".  Value is returned
# as a single quoted path string.  
# TODO: add options to specify separator
#       add flag for escaped instead of quoted return
function assemble_bash_safe_path() {
  components=()
  for arg in "$@"; do 
    IFS='/' read -r -a components <<< "${arg}"
  done
  printf -v safesinglequotepath "'/%s'" "${components[@]%/}"
}

if [[ $(uname) == "Linux" ]]; then
  source $D/linuxutil.sh
elif [[ $(uname) == "Darwin" ]]; then
  source $D/macutil.sh
fi

function is_int() {
  local string="${1:-}"
  case $string in
    ''|*[!0-9]*) return 1 ;;
    *) return  ;;
  esac
}

# Args: first term larger int than second term.  
#     if first term is "". we treat it as 0
function gt() {
  term1="${1:-}"
  term2="${2:-}"
  if is_int ${term1}; then 
    if is_int ${term2}; then
      if [ ${term1} -gt ${term2} ]; then
        return 0
      else
        return 1
      fi
    fi
  elif [[ "${term1}" == "" ]]; then
    return 1
  fi
}

function lt() {
  term1="${1:-}"
  term2="${2:-}"
  if is_int ${term1}; then 
    if is_int ${term2}; then
      if [ ${term1} -lt ${term2} ]; then
        return 0
      else
        return 1
      fi
    fi
  elif [[ "${term1}" == "" ]]; then
    return 1
  fi
}

# you can't pass arrays around as args in bash, but if you do 
# a global declare you can copy it out of the env
declare -ga dirarray
function finddir_array() {
  set=false
  depth=1
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

# though you can't pass arrays around as arguments (See above)
# you can pass a named reference and address it on the other side
function components_to_path() {
  name=$1[@]
  path_components=("${!name}")
  IFS='/' read -r -a path_components <<< "${path_to_plist}"
  printf -v path "/%s" "${path_components[@]%/}"
  printf "%s" "${path#/}"
}

fsdate_fmt='%Y%m%d_%H%M%S'
function fsdate() {
  date "+${fsdate_fmt}"
}

most_recent() {
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
