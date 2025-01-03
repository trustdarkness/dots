#!/usr/bin/env bash

# This file contains generally os-agnostic (POSIX-ish, though also WSL)
# functions and utilities that shouldn't be too annoying to keep handy
# in the env of an interactive sessionn, but also as a sort of personal 
# stdlib for inclusion in scripts.  If a script is something I think 
# others might want to check out and use it, I try to make it self 
# contained, as things in this file do reference specific bits of my setup
# that others won't have, however, I've tried to make it relatively 
# safe for that use case as well YMMV and there shall be no expectations,
# warranty, liability, etc, should you break something.
# 
# github.com/trustdarkness
# GPLv2 if it should matter
# Most things should work on old versions of bash, but really bash 4.2+ reqd
# 
# OS detection and loading of os-specific utils is toward the botton, 
# line 170+ish at the time of writing. 
#####################  internal logging and bookkeeping funcs
#############################################################

# colors for logleveled output to stderr
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
 
#      TIMESTAMP [FUNCTION] [LEVEL] PID FILENAME:LINENO
LOGFMT="%12s [%s] %s %s %s"
if [ -n "$XDG_STATE_HOME" ]; then 
  LOGDIR="$XDG_STATE_HOME/com.trustdarkness.dots"
else
  LOGDIR="$HOME/Library/Logs/com.trustdarkness.dots"
fi
export LOGDIR
mkdir -p "$LOGDIR"

LOG_LEVELS=( ERROR WARN INFO DEBUG )

# Given a log level name (as above), return
# a numeric value
# 1 - ERROR
# 2 - WARN
# 3 - INFO
# 4 - DEBUG
get_log_level() {
  idx=0
  for level in "${LOG_LEVELS[@]}"; do 
    if [[ "$level" == "${1:-}" ]]; then 
      echo $idx
      return 0
    fi
    ((idx++))
  done 
  return 1
}

# Strip any coloring or brackegs from a log level
striplevel() {
  echo "${1:-}"|sed 's/\x1B\[[0-9;]*[JKmsu]//g'|tr -d '[' |tr -d ']'
}

# based on the numeric log level of this log message
# and the threshold set by the current user, function, script
# do we echo or just log?  If threshold set to WARN, it 
# means we echo WARN and ERROR, log everything
to_echo() {
  this_log=$(get_log_level "${1:-}")
  threshold=$(get_log_level "${2:-}")
  if le "$this_log" "$threshold"; then 
    return 0
  fi
  return 1
}

# Log to both stderr and a file (see above).  Should be called using
# wrapper functions below, not directly
_log() {

  local ts=$(fsts)

  local pid="$$"
  src="${BASH_SOURCE[-1]}"
  bn=$(basename "$src")
  local funcname="${FUNCNAME[2]}"
  local level="$1"
  shift
  local message="$@"
  if [ -z "$LOGFILE" ]; then 
    LOGFILE="$LOGDIR/$src.log"
  fi
  printf -v line_leader "$LOGFMT" "$ts" "$funcname" "$level" "pid: ${pid}" "$src: $lineno" \
     
  (
     this_level=$(striplevel "$level")
    if to_echo $this_level $LEVEL; then 
      #exec 3>&1 
      # remove coloring when going to logfile 
      echo "$line_leader $message${RST}" 2>&1 | sed 's/\x1B\[[0-9;]*[JKmsu]//g' | tee -a "$LOGFILE" 
    else
      echo "$line_leader $message${RST}" | sed 's/\x1B\[[0-9;]*[JKmsu]//g' >> "$LOGFILE"
    fi
  )
  return 0
}

# Templates for colored stderr messages
printf -v E "%s[%s]" $ERR "ERROR"
printf -v W "%s[%s]" $WRN "WARN"
printf -v I "%s[%s]" $INF "INFO"
printf -v B "%s[%s]" $DBG "DEBUG"

# wrappers for logs at different levels
error() { 
  _log $E "$@"; return $?
}

warn() { 
  _log $W "$@"; return $?
}

info() { 
  _log "$I" "$@"; return $?
}

debug() { 
  _log "$B" "$(prvars) $@"; return $?
}

################# helper functions for catching and printing
# errors with less boilerplate (though possibly making it 
# slightly more arcane).  an experiment

# print status, takes a return code
prs() {
  s=$1
  printf "${STAT}\$?:$RST %d " "$s"
}

# print variables, takes either a list of variable names
# (the strings, not the vars themselves) or looks in a 
# global array ${logvars[@]} for same
prvars() {
  if [ $# -gt 0 ]; then 
    for arg in "$@"; do 
      logvars+=( "$arg" )
    done
  fi
  for varname in "${logvars[@]}"; do 
    n=$varname
    v="${!n}"
    if [ "${#v[@]}" -gt 1 ]; then 
      printf "${VAR}%s=( ${RST}" "$n"
      printf "%s " "${v[@]}"
      printf "${VAR})"
    fi
    printf "${VAR}%s:${RST} %s " "$n" "$v"
  done     
  logvars=()
  return 0
}

# prints command, arguments, and output
prcao() {
  c="${1:-}"
  a="${2:-}"
  o=$(echo "${3:-}"|xargs)
  e=$(echo "${4:-}"|xargs)
  printf "${CMD}cmd:$RST %s ${CMD}args:$RST %s ${CMD}stdout:$RST %s ${CMD}stderr:$RST %s " "$c" "$a" "$o" "$e"
}

# print a structured error, when the command with arguments, 
# other relevant vars, exit status, and output, says all that needs
# to be said
# Args: return code, command, args, output, stderr
struct_err() {
  ret=$1
  cmd=$2
  args=$3
  out=$4
  err=$5
  retm=$(prs "$ret")
  varsm=$(prvars)
  com=$(prcao "$cmd" "$args" "$out" "$err")
  printf -v error_msg "%s %s %s" "$retm" "$varsm" "$com"
  error "$error_msg"
}

# runs a command, wrapping error handling
# args: command to run, args
lc() {
  cmd="$1"; shift
  #info "lc: $cmd $@"
  {
      IFS=$'\n' read -r -d '' err;
      IFS=$'\n' read -r -d '' out;
      IFS=$'\n' read -r -d '' ret;
  } < <((printf '\0%s\0%d\0' "$($cmd $@)" "${?}" 1>&2) 2>&1)
  if [ $ret -gt 0 ]; then 
    struct_err "$ret" "$cmd" "$@" "$out" "$err"
    return $ret
  else
    echo "$out" && return 0
  fi
}

alias vsc="vim $HOME/.ssh/config"
alias pau="ps auwx"
alias paug="ps auwx|grep "
alias paugi="ps awux|grep -i "
alias rst="sudo shutdown -r now"
alias gh="mkdir -p $HOME/src/github && cd $HOME/src/github"
alias gl="mkdir -p $HOME/src/gitlab && cd $HOME/src/gitlab"
alias gc="git clone"
export GH="$HOME/src/github"

MODERN_BASH="4.3"

if ! declare -F "exists" > /dev/null 2>&1; then
  source "$D/existence.sh"
fi

# A slightly more convenient and less tedious way to print
# to stderr, canonical in existence # TODO, check namerefs on resource
if ! is_declared "se"; then
  # Args: 
  #  Anything it recieves gets echoed back.  If theres
  #  no newline in the input, it is added. if there are substitutions
  #  for printf in $1, then $1 is treated as format string and 
  #  $:2 are treated as substitutions
  # No explicit return code 
  function se() {
    if [[ "$*" == *'%'* ]]; then
      >&2 printf "${1:-}" $:2
    else
      >&2 printf "$@"
    fi
    if ! [[ "$*" == *'\n'* ]]; then 
      >&2 printf '\n'
    fi
  }
fi

# for my interactive shells, the full environment setup is constructed
# from bashrc, but for scripts that rely on it, this function should be
# called to make sure all is as expected.
# TODO: create teardown that remove all namerefs added by setup
function util_env_load() {
  # this represents all the possible sources at the moment, but only
  # including as options as needed, otherwise it would be taking an 
  # already silly thing and making it ridiculous.
  local exu=true
  local up=false
  local fsau=false
  local osu=true
  local jl=false
  local xl=false
  local ku=false
  local lb=false
  local bsu=false
  local iu=false
  local mb=false
  local md=false
  local bc=false
  local bs=false
  local POSITIONAL_ARGS=()
  while [ $# -gt 0 ]; do
    case "${1:-}" in
      "-f"|"--filesystemarray")
        fsau=true
        shift
        ;;
      "-j"|"--json-like")
        jl=true
        shift
        ;;
      "-x"|"--xml-like")
        xl=true
        shift
        ;;
      "-u"|"--user-prompts")
        up=true
        shift
        ;;
      "-i"|"--installutil")
        iu=true
        shift
        ;;
      "-d"|"--macdebug")
        md=true
        shift
        ;;
      "-b"|"--bootstraps")
        bs=true
        shift
        ;;
      *)
        echo "Boo.  ${1:-} does not exist"
        shift 
        ;;
    esac
  done
  if ! declare -F "exists" > /dev/null 2>&1 && $exu; then
    source "$D/existence.sh"
  fi
  if undefined "confirm_yes" && $up; then
    source "$D/user_prompts.sh"
  fi
  if undefined "xmllike" && $xl; then
    source "$D/xml_like.sh"
  fi
  if undefined "json_like_tl" && $jl; then
    source "$D/json_like.sh"
  fi
  if undefined "dirarray" && $fsau; then
    source "$D/filesystemarrayutil.sh"
  fi
  if undefined "binmachheader" && $md; then
    source "$D/macdebug.sh"
  fi
  if untru $osutil_in_env && $osu; then
    osutil_load
  fi
  if undefined "sau" && $iu; then
    install_util_load
  fi
  if undefined "term_bootstrap" && $bs; then 
    source "$D/bootstraps.sh"
  fi
}

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

function clipcap() {
  flag=true
  trap ctrl_c INT
  ctrl_c () {
    export flag=false
  }
  declare -ga captured
  while true; do 
    clipnotify
    captured+=( xclip -o )
  done
  echo "${captured[@]}"
}

function symlink_verbose() {
  se "linking target $target from link name $linkname"
  ln -sf "$target" "$linkname"
}
 
# TODO: make this less brittle
function move_verbose() {
  mvv_force=false
  if [[ "${1:-}" == "-f" ]]; then 
    mvv_force=true
    shift
  fi
  printf "moving %s to %s" "${1:-}" "${2:-}"
  if tru $mvv_force; then
    echo " with -f"
    mv -f "${1:-}" "${2:-}"
  else
    echo
    mv "${1:-}" "${2:-}"
  fi
} 

function lns() {
  local target="${1:-}"
  local linkname="${2:-}"
  if [ -h "$linkname" ]; then 
    ln -si "$target" "$linkname"
  elif [ -f "$linkname" ]; then
    move_verbose "$linkname" "$linkname.bak"
    symlink_verbose "$target" "$linkname"
  else
    symlink_verbose "$target" "$linkname"
  fi  
}

function lnsdh() {
  lns "$D/${1:-}" "$HOME/${1:-}"
}

function gpgvc() {
  gpg --verify < <(xclip -o)
}

function gpgic() {
  gpg --import < <(xclip -o)
}

# preferred format strings for date for storing on the filesystem
FSDATEFMT="%Y%m%d" # our preferred date fmt for files/folders
printf -v FSTSFMT '%s_%%H%%M%%S' "$FSDATEFMT" # our preferred ts fmt for files/folders
LAST_DATEFMT="%a %b %e %k:%M" # used by the "last" command

function fsdate() {
  date +"${FSDATEFMT}"
}

function fsts_to_fsdate() {
  date -d -f "$FSTSFNT" "${1:-}" "$FSDATEFMT"
}

function fsts() {
  date +"${FSTSFMT}"
}

function is_fsts() {
  fsts_to_unixtime > /dev/null 2>&1
  return $?
}

function is_fsdate() {
  date "+$FSDATEFMT" -d "${1:-}" > /dev/null 2>&1
  return $?
}

function fsts_to_unixtime() {
  if is_mac; then
    date -jf "$FSTSFMT" "${1:-}" +%s
  else
    date -d -f "$FSTSFNT" "${1:-}" +"%s"
  fi
  return $?
}

function colnum() {
  help() {
    echo "echos the column number of substring in string if found"
    echo "returns 0 if successful, 255 if substring not found, 1 otherwise"
    return ${1:-0}
  }
  to_split="${@:$OPTIND:1}"
  substring="${1:-}"
  string="${2:-}"
  if empty "$substring" || empty "$string"; then 
    help 1
  fi
  # found=$(grep "$substring" <<< "$string")
  # if [ $? -gt 0 ]; then
  #   return 255
  # fi
  rest=${string#*$substring}
  se "$rest"
  c=$(( ${#string} - ${#rest} - ${#substring} ))
  if gt $c 0; then
    echo $C
    return 0
  else
    return 255
  fi
  return 1
}

# Normalize os detection for consistency, hopefully reducing the chance
# of simple typo, etc mistakes and increasing readability
function is_mac() {
  if [[ "$(uname)" == "Darwin" ]]; then
    return 0
  fi
  return 1
}

function is_linux() {
  if [[ "$(uname)" == "Linux" ]]; then
    return 0
  fi
  return 1
}

  function what_os() {
    if is_mac; then echo "MacOS"; return 0; fi
    if is_linux; then echo 'GNU/Linux'; return 0; fi
  }
# fi

function pidinfo() {
  local line="$(ps awux | grep ${1:-})"
  local dirtyname="$(echo \"$line\" | awk -F':' '{print$NF}')"
  echo $dirtyname
  local name="${dirtyname:6}"
  local cpu="$(echo \"$line\"|awk '{print$3}')"
  local mem="$(echo \"$line\"|awk '{print$4}')"
  local started="$(echo \"$line\"|awk '{print$9}')"
  IFS='' read -r -d '' pidinfo <<"EOF"
 Process: %s
   PID: %s
   Current CPU: %s %%
   Current RAM: %s %%
   Started at: %s
EOF
  printf "$pidinfo" "$name" "$cpu" "$mem" "$started"
}

function add_permanent_alias() {
  name="${1:-}"
  to="${2:-}"
  rationale="${3:-}"
  ts=fsts
  if [ -n "$to" ] && ! is_quoted "$to"; then
    to=$(shellquote "$to")
  fi
  mkdir -p "$HOME/.local/bak"
  fs_rationale=$(echo "$rationale"|sed  's/ /_/g')
  se "existing .bashrc backed up to $HOME/.local/bak/.bashrc.bak.$ts.$fs_rationale"
  # https://stackoverflow.com/questions/5573683/adding-alias-to-end-of-alias-list-in-bashrc-file-using-sed
  tac .bashrc | 
  awk "FNR==NR&&/alias/{s=FNR;next}FNR==s{ \$0=\$0\"\nalias $name=\x22$to\x22\n\"}NR>FNR" .bashrc .bashrc > .bashrc.new 
  mv "$D/.bashrc" "$HOME/.local/bak/.bashrc.bak.$ts.add_synergy_alias" && mv .bashrc.new .bashrc
  return $?
}

function is_bash_script() {
  if [ -z "$script" ] || ! [ -f "$script" ]; then
    return 1
  fi
  head -n1 "$script" | grep "bash$" > /dev/null 2>&1
  return $?
}

function function_finder() {
  script="${1:-}"
  if ! is_bash_script; then
    se "please provide a path to a bash script"
  fi
  if ! declare -p "VALID_DECLARE_FLAGS" > /dev/null 2>&1; then 
    source "$D/existence.sh"
  fi
  declare -a _names
  _names+=( $(grep ^function "$script" |awk '{print$2}'|awk -F'(' '{print"\x22"$1"\x22"}') )
  if gt $? 0; then
    se "could not find any functions in the global namespace in $script"
    return 1
  fi
  for name in "${_names[@]}"; do
    echo "$name"
  done
}

function namerefs_bashscript_add() {
  script="${1:-}"
  if ! is_bash_script; then
    se "please provide a path to a bash script"
  fi
  if ! declare -p "VALID_DECLARE_FLAGS" > /dev/null 2>&1; then 
    source "$D/existence.sh"
  fi
  if undefined "in_array"; then 
    source "$D/filesystemarrayutil.sh"
  fi

  # our main container for names
  declare -a _names

  # case: global function names
  _names=$(function_finder)

  # get variables declared as local for exclusion (this may ressult in false positives)
  declare -ga localvars
  declare -a localvarlines
  localvarlines=( $(grep '^[[:space:]]*local [[:alnum:]]*_*[[:alnum:]]*' "$script") )
  for line in "${localvarlines[@]}"; do 
    wequal=$(echo "$line"|grep "=")
    if [ $? -eq 0 ]; then
      # we're expecting something like "local foo=bar" and we want foo
      localvars+=( $(echo "$wequal" | awk '{print$1}' |awk -F'=' '{print$1}') )
    else
      localvars+=( $(echo "$line" | awk '{print$2}') )
    fi
  done

  # case variables declared by assignment
  declare -a vars
  vars=$(grep '^[[:space:]]*[[:alnum:]]*_*[[:alnum:]]*=' "$script" |awk -F'=' '{print$1}'|xargs)

  # case: names declared in the global scope
  vars+=( $(grep ^declare "$script" |awk '{print"\x22"$3"\x22"}') )

  # case: variables assigned by printf
  vars+=( $(grep "printf -v" "$script" |awk '{print"\x22"$3"\x22"}') )

  # only populate from the above 2 cases when not declared with the local keyword
  for var in "${vars[@]}"; do
    if ! in_array "$var" "localvars"; then 
      var=$(singlequote "$var")
      _names+=( "$var" )
    fi
  done

  # names declared not in the global namespace but with -g
  printf -v declaregregex '^[[:space:]]*declare -[%s]*g[%s]*' "$VALID_DECLARE_FLAGS" "$VALID_DECLARE_FLAGS"
  _names+=( $(grep "$declaregregex" "$script" |awk '{print"\x22"$3"\x22"}') )

  noextbasename=$(basename "$script"|sed 's/.sh//g')
  expected_name="NAMEREFS_${noextbasename^^}"
  existing_namerefs="$(grep '^NAMEREFS_[[A-z]]=(.*)$')"
  if [ $? -eq 0 ]; then
    name=$(echo "$existing_namerefs"|awk -F'=' '{print$1}')
    if [[ "$name" == "$expected_name" ]]; then 
      eval "$existing_namerefs"
    else 
      se "found $name in $script which didn't match expected $expected_name"
      return 1
    fi
  fi
  if undefined "$expected_name"; then 
    declare -a "$expected_name"
  fi
  local -n script_namerefs=("${!expected_name[@]}")
  script_namerefs+=( $_names )
  # make sure we're quoted for printing 
  declare -a out_namerefs
  for nameref in "${script_namerefs[@]}"; do
    if ! is_quoted "$nameref"; then
      out_namerefs+=( $(singlequote "$nameref") )
    else
      out_namerefs+=( "$nameref" )
    fi
  done
  # remove the original reference
  sed -i 's/^NAMEREFS_[[A-z]]=(.*)$//g' "$script"
  # add it in a nice-to-look-at format:
  printf "\n\n${expected_name}=(" >> "$script"
  for quoted_nameref in "${out_namerefs[@]}"; do 
    printf "$quoted_nameref" >> "$script"
  done
  printf ")\n" >> "$script"
}



# find wrappers for common operation modes, even when they vary by OS.
# This is the kind of thing that should normally go in osutil, but
# there is something useful about seeing the differences side-by-side
# and not having to be concerned that any troubleshooting might be OS
# specific.  We capture the args just like as if we were running the 
# real find and populate our changes into the args dict in an order that
# shouldn't disrupt the original intention.  To ease troubleshooting,
# we export three globals on run:
# [L,M,C]FIND_IN - $@ array as it was passed to the function
# [L,M,C]FIND_RUN - full command as it was run, including any local 
#                   alteration to handles; but nothing external, pipelines, etc
# [L,M,C]FIND_STACK - the call stack ${FUNCNAME[@]} at execution
#
# (TODO: would it be useful to keep in-memory
# histories in global arrays?)
COMPOSABLE_FINDS=( "cfind" "lfind" )

function compose_find() {
set -x
  caller="${FUNCNAME[1]}"
  to_compose=( "$@" )
  local -n run_args="${caller^^}_RUN"
  caller_args=("${run_args[@]:1}")
  composed=false
  declare -A called
  # jacob told me that I am a candidate, do you know what that means?
  for candidate in "${COMPOSABLE_FINDS[@]}"; do 
    if [[ "$candidate" != "$caller" ]]; then
      if [[ "${to_compose[*]}" == *"$candidate"* ]]; then
        # candidate is in the call stack
        composed=true
        called["$candidate"]="$caller"
        caller="$candidate"
        run_args=( $(eval "${candidate}_args" "${run_args[@]}") )
      fi
    fi
  done
  # let us do a little validation; our wrong side of the tracks unit tests
  if $composed; then
    if [[ "${caller_args[*]}" == "${run_args[*]}" ]]; then
      se "find should be composed but only found args from ${FUNCNAME[1]}"
      se "should have found:"
      for caller in "${!called[@]}"; do 
        se "$caller : ${called[$caller]}"
      done
      return 2
    fi
    declare -a missing_caller_args
    for caller in "${!called[@]}"; do 
      if [[ "$caller" == "${FUNCNAME[1]}" ]]; then
        local_caller_args=( "${caller_args[@]}" )
      else
        local_caller_args=( $"${caller^^}_RUN" )
      fi
      for arg in "${local_caller_args[@]}"; do 
        if [[ "${run_args[*]}" != *"$arg"* ]]; then
          missing_caller_args+=( "$arg" )
        fi
      done
      if gt ${#missing_caller_args[@]} 0; then
        se "all caller_args should have been in \$run_args, but $caller were missing:"
        se "${missing_caller_args[@}}"
        return 3
      fi
    done
  fi
  find "${run_args[@]:1}"
  return $?
}

function find_composed_of() {
set -x
  caller="${FUNCNAME[1]}"
  in_args="${caller^^}_IN"
  declare -a new_args
  for arg in "${in_args[@]}"; do
    if [[ "$arg" != "find" ]] && [[ "$arg" != "$caller" ]]; then
      if [[ "${COMPOSABLE_FINDS[@]}" != *"$arg"* ]]; then
        new_args+=( "$arg" )
      else
        composed=true
        to_compose+=( "$arg" )
      fi
    fi
  done
  in_args=( "${new_args[@]}" )
  if gt ${#to_compose[@]} 0; then
    echo "${to_compose[@]}"
    return 0
  fi
  return 1
}

# ignores network shares. "L" for local.
function lfind_args() {


  # we delineate argv as 
  #       0    1    2       3             4
  # Linux find $dir -mount  $otherargs...     
  # Mac   find $dir -fstype local         $otherargs....
  # we will drop arg0 when calling find, but leave it for env record keeping
  LFIND_RUN+=( "find" )
  case $(what_os) in
    "MacOS")
      LFIND_RUN+=( "-fstype" )
      LFIND_RUN+=( "local" )
      ;;
    'GNU/Linux')
      LFIND_RUN+=( "-mount" )
      ;;
  esac
  LFIND_RUN+=( "find" )
  LFIND_RUN+=( "${LFIND_IN[1]}" )
  LFIND_RUN+=( "${argv2[@]}" )
  if gt $# 2; then
    LFIND_RUN+=( "${LFIND_IN[@]:2}" )
  fi  

  echo "${LFIND_RUN[@]:1}"
  return 0
}

function lfind() {
  declare -ga LFIND_IN
  declare -ga LFIND_RUN
  declare -ga LFIND_STACK
  LFIND_STACK=( "${FUNCNAME[@]}" )
  LFIND_IN=( "$@" )
  if to_compose_str=$(find_composed_of); then
    composed=true
  fi
  lfind_args "$@"
  if $composed; then
    compose_find "${to_compose[@]}"
    return $?
  fi
  find "${LFIND_RUN[@]}"
}

# clear find, do not print stderr to the console.
# stderr can be found at $CACHE/cfind/last_stderr
# we also save the previous at $CACHE/cfind/last_last_stderr
# but no more silliness beyond that
# where $CACHE is ~/.local/cache on Linux and 
# ~/Library/Application\ Support/Caches on Mac
function cfind_args() {
  mkdir -p "$CACHE/cfind"
  errfile="$CACHE/cfind/last_stderr"
  prev_errfile="$CACHE/cfind/last_last_stderr"
  if [ -f "$prev_errfile" ]; then 
    rm -f "$prev_errfile"
  fi
  if [ -f "$errfile" ]; then
    mv "$errfile" "$prev_errfile"
  fi
  CFIND_RUN=( "find" "${CFIND_IN[@]}" "2>" "$errfile" )
  if $composed; then
    compose_find "$to_compose_str"
    return $?
  fi
  find "${CFIND_RUN[@]:1}"
  return $?
} 

function cfind() {
  declare -ga CFIND_IN
  declare -ga CFIND_RUN
  declare -ga CFIND_STACK
  composed=false
  CFIND_STACK=( "${FUNCNAME[@]}" ) 
  CFIND_IN=( "$@" )
  if to_compose_str=$(find_composed_of); then
    composed=true
  fi
  cfind_args "$@"
  if $composed; then
    compose_find "${to_compose[@]}"
    return $?
  fi
  find "${CFIND_RUN[@]}"
}

# now we can define silly things like 
function clfind() {
 cfind lfind "$@"
}
  

# If for any sourced file, you'd like to be able to undo the 
# changes to  your environment after it's sourced, track the
# namerefs (variable, function, etc names) in an array named
# sourcename_namerefs where the sourced filename is 
# sourcename.sh, when you want to clean the namespace of that
# file, call cleaup_namespace sourcename, and it will be done
# see macboot.sh for example
function cleanup_namespace() {
  local namespace="${1}"
  local -n to_clean="${namespace}_namerefs"
  to_clean=${!to_clean}
  for nameref in "${to_clean[@]}"; do 
    unset ${nameref}
  done
}

# for things you only want there when the above DEBUG flag is set
# function debug() {
#   if $DEBUG; then
#     if [ $# -eq 2 ]; then 
#       >&2 printf "${1:-}\n" "${@:2:-}"
#     else
#       >&2 printf "${1:-}\n"
#     fi
#   fi
# }

# Arg1 is needle, Arg2 is haystack
# returns 0 if haystack contains needle, retval from grep otherwise
function string_contains() {
  echo "${@:2}"| grep -Eqi "${1:-}" 
  return $?
}
alias stringContains="string_contains"

function shellquote() {
  if [[ "$1" =~ ".*" ]]; then 
    echo $1
  fi
  printf '"%s"\n' "$@"
}

# returns zero if the value referenced by $1 has literal quotes surrounding it
# works for single or double quotes, returns 1 otherwise
function is_quoted() {
  if [[ "${1:-}" =~ \'.*\' ]]; then
    return 0
  elif [[ "${1:-}" =~ \".*\" ]]; then 
    return 0
  fi
  return 1
}

# for a multiline string, returns a string with doublequotes surrounding
# each line of the given string as a part of the string
function shellquotes() {
  for line in ${1:-}; do 
    shellquote "${line}"
  done
}

# returns given args as strings with single quotes surrounding
function singlequote() {
  printf "'%s'\n" "$@"
}

# for a multiline string, returns a string with singlequotes surrounding
# each line of the given string as a part of the new string
function singlequotes() {
  for line in ${1:-}; do 
    singlequote "${line}"
  done
}

# shell escapes terms given as arguments (%q)
function shellescape() {
  printf "%q\n" "$@"
}

# for a multiline string, returns a string with each line of the new string
# being a shell quoted version of the original (%q)
function shellescapes() {
  for line in ${1:-}; do 
    shellescape "${line}"
  done
}

# Returns the architecture of the running system
function system_arch() {
  uname -m
}

# Appends Arg1 to the shell's PATH and exports
function path_append() {
  to_add="${1:-}"
  if [ -d "${to_add}" ]; then 
    if ! [[ "${PATH}" == *"${to_add}"* ]]; then
      export PATH="${PATH}:${to_add}"
    fi
  fi
}

# Prepends Arg1 to the shell's PATH and exports
function path_prepend() {
  to_add="${1:-}"
  if [ -f "${to_add}" ]; then 
    if ! [[ "${PATH}" == *"${to_add}"* ]]; then
      export PATH="${to_add}:${PATH}"
    fi
  fi
}


function printcolrange() {
  input="${1:-}"
  start="${2:-}"
  fin="${3:-}"
  delim="${4:-}"
  top="$t"
  if lt "$fin" 0; then
    prog='{for(i=f;i<=t'+$fin+';i++) printf("%s%s",$i,(i==t)?"\n":OFS)}'
  else
    prog='{for(i=f;i<=t;i++) printf("%s%s",$i,(i==t)?"\n":OFS)}'
  fi
  echo "$input"|awk "$start,NF$fin { print NR, $0 }"
}

# Given a date (Arg1) and a fmt string (Arg2, strftime), 
# returns 0 if that date was more than 7 days ago, 1 otherwise
function is_older_than_1_wk() {
  d="${1:-}"
  fmt="${2:-}"
  if ! [ -n "${fmt}" ]; then 
    if [ "${#d}" -eq 8 ]; then
      fmt=$FSDATEFMT
    elif [ "${#d}" -eq 15 ]; then
      fmt=$FSTSFMT
    else
      se "Please provide a date format specifier"
      return 1
    fi
  fi
  ts=$(date -f +"$fmt" -d "${d}" +"%s")
  now=$(date +"%s")
  time_difference=$((now - ts))
  days=$((time_difference / 86400)) #86400 seconds per day
  if [ $days -gt 7 ]; then 
    return 0
  fi
  return 1
}

function update_ssh_ip() {
  host="${1:-}"
  octet="${2:-}"
  out=$(grep -A2 "$host" $HOME/.ssh/config)
  local IFS=$'\n'
  for line in out; do
    line=$(echo $line |xargs)
    ip=$(grep "hostname" <<< "$line" | awk '{print$2}')
  done
  printf -v sedexpr "s/%s/%s/g" "$ip" "10.1.1.$octet"
  sed -i "$sedexpr" "$HOME/.ssh/config"
}

# this only kinda sorta works IIRC
# Intended to grab ip or hostname values from the nearest source possible
# starting with /etc/hosts, .ssh/config, then out to dig, other place
# echo hostname or ip from host alias to the console no explicit return
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


# NOT currently working 
# function show_global_scope_declares() {
#   script="${1:-}"
#   if is_bash_script "script"; then 
#     declare -a ifs 
#     declare -a fis
#     declare -a fors
#     declare -a whiles
#     declare -a dones
#     for lineno in $(grep -n ^if "$script"|awk -F":" '{print$1}'); do 
#       ifs+=( $lineno )
#     done
#     for lineno in "${ifs[@]}"; do 
#       fis+=( $(tail -n $lineno "$script" |grep ^fi |head -n 1| awk -F":" '{print$1}') )
#     done
#     for lineno in $(grep -n ^for "$script"|awk -F":" '{print$1}'); do 
#       fors+=( $lineno )
#     done
#     for lineno in "${fors[@]}"; do 
#       dones+=( $(tail -n $lineno "$script" |grep ^done |head -n 1| awk -F":" '{print$1}') )
#     done
#     ifctr=0
#     forctr=0
#     for line in $(grep -E -v '(^[[:space:]]|^}|^done|^END|^#|^EOF)' "$script"); do 
#       case "$(echo line|awk '{print$1}')" in 
#         "if")
#           cat "$script" | head -n "${ifs[$ifctr]}" | tail -n "${fis[$ifctr]}"
#           ((ifctr++))
#           ;;
#         "for")
#           cat "$script" | head -n "${fors[$forctr]}" | tail -n "${dones[$forctr]}"
#           ((forctr++))
#           ;;
#         *)
#           echo $line
#           ;;
#       esac
#     done
#   fi
# }

# does a best effort search of a bash source file $2 
# and attemtps to determine if the given function $1 
# is called in that file, returns 0 if so and echos
# the surrounding code to the console, 1 if not found
# or indeterminite
function is_called() {
  func="${1:-}"
  found=$(grep -n -B3 -A3 "$func" "${2:-}" |grep -v '^#' |sed "s/$func/${RSL}${func}${RST}/g")
  echo "$found"
}

function is_absolute() {
  local dir="${1:-}"
  if [ -d "${dir}" ]; then 
    if startswith "/" "${dir}"; then 
      return 0
    fi
  fi
  return 1
}

function startswith() {
  local query="${2:-}"
  local starts_with="${1:-}"
  if [[ "$query" =~ ^$starts_with.* ]]; then 
    return 0
  fi
  return 1
}

function symlink_child_dirs () {
   undo_dir="$CACHE/com.trustdarkness.utilsh"
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
  TARGET="${@:$OPTIND:1}"
  WHERETO="${@:$OPTIND+1}"
 
  failures=0
  successes=0
  declare -a failed_targets
  declare -a undos
  if [ -d "$TARGET" ]; then
    if ! is_absolute "$TARGET"; then 
      echo "the target directory should be an absolute path"
      return 1
    fi
    if [ -d "$WHERETO" ]; then
      if find $TARGET ! name '.git' -maxdepth 1 -type d -exec ln -s '{}' $WHERETO/ \;; then
        undos+=( "$WHERETO/$TARGET" )
        ((successes++))
      else
        ((failures++))
        failed_targets+=( "$WHERETO/$TARGET" )
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

# thats too long to type though.
alias scd="symlink_child_dirs"

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

# Convenience function for github clone, moves into ~/src/github, 
# clones the given repo, and then cds into its directory
function ghc () {
  if [ $# -eq 0 ]; then
    url="$(xclip -out)"
    if [ $? -eq 0 ]; then
      se "No url given in cmd or on clipboard."
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

function gits() {
  git status
}

function is_my_git_repo() {
  local dir="${1:-}"
  if [ -d "$(pwd)/${dir}" ]; then 
    user=$(grep -A1 'remote "origin"' "$(pwd)/${dir}/.git/config" |\
      tail -n1| \
      awk -F':' '{print$2}'| \
      awk -F'/' '{print$1}')
    if [[ "$user" == "trustdarkness" ]]; then 
      return 0
    fi
  fi
  return 1
}

 # super sudo, enables sudo like behavior with bash functions
function ssudo () {
  [[ "$(type -t $1)" == "function" ]] &&
    ARGS="$@" && sudo bash -c "$(declare -f $1); $ARGS"
}
alias ssudo="ssudo "

function is_alpha_char() {
  local string="${1:-}"
  if [ -n "$string" ] && [[ "$string" =~  [A-z] ]]; then 
    return 0
  fi
  return 1 
}

# To help common bash gotchas with [ -eq ], etc, this function simply
# takes something we hope to be an int (arg1) and returns 0 if it is
# 1 otherwise
function is_int() {
  local string="${1:-}"
  case $string in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
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

# Args: first term we hope is less than the second.
# returns 0 if it is, 1 otherwise. if first term is "", return 1
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

# Args: first term we hope is less than the second.
# returns 0 if it is, 1 otherwise. if first term is "", return 1
function le() {
  term1="${1:-}"
  term2="${2:-}"
  if is_int ${term1}; then 
    if is_int ${term2}; then
      if [ ${term1} -le ${term2} ]; then
        return 0
      else
        return 1
      fi
    fi
  elif [[ "${term1}" == "" ]]; then
    return 1
  fi
}

function boolean_or {
  for b in "$@"; do
    # se "testing ${b}"
    if [ -n "${b}" ]; then 
      if is_int ${b}; then
        if [ ${b} -eq 0 ]; then
          return 0
        fi
      else
        if ${b}; then
          return 0
        fi
      fi
    fi
  done
  return 1
}

function sata_bus_scan() {
  sudo sh -c 'for i in $(seq 0 4); do echo "0 0 0" > /sys/class/scsi_host/host$i/scan; done'
}

function get_cache_for_OS () {
  case $(what_os) in 
    'GNU/Linux')
      CACHE="$HOME/.local/cache"
      OSUTIL="$D/linuxutil.sh"
      function sosutil() {
        source "$D/linuxutil.sh"
      }
      alias vosutil="vim $D/linuxutil.sh && sosutil"
      ;;
    "MacOS")
      CACHE="$HOME/Library/Application Support/Caches"
      OSUTIL="$D/macutil.sh"
      alias sosutil="source $D/macutil.sh"
      alias vosutil="vim $D/macutil.sh && vosutil"
      ;;
  esac
  export cache
}
get_cache_for_OS

function user_feedback() {
  local subject
  local message
  local detritus
  if [[ $# -gt 1 ]]; then 
    subject="${1:-}"
    message="${2:-}"
    detritus="${@: 2}"
  else
    # https://askubuntu.com/questions/543553/write-to-syslog-from-the-command-line
    subject="${0##*/}[$$]"
    message="${1:-}"
  fi
  log_message() {
    if [[ "$subject" != "${0##*/}[$$]" ]]; then 
      printf -v log "%s %s %s" "${0##*/}[$$]" "$subject" "$message"
    else 
      printf -v log "%s %s" "$subject" "$message"
    fi
  }
  nix_notify() {
    if [[ $DISPLAY ]]; then
      if notify-send "$subject" "$messsage"; then 
        return 0
      else
        errors+=("notify-send: $?")
      fi
    else
      log_message
      if $logger "$log"; then 
        return 0
      else
        errors+=("$logger: $?")
      fi
    fi
  }
  bold=$(tput bold)
  normal=$(tput sgr0)
  declare -a errors
  case $- in
    *i*)
      printf "${bold}$subject${normal} -- $message"
      if [ -n "$detritus" ]; then printf "$detritus"; fi
      printf "\n"
      return 0
      ;;    
    *)
      case $($what_os) in
        "GNU/Linux")
          logger=logger
          nix_notify
          ;;
        "MacOS")
          if [[ $(check_macos_gui) ]]; then
            printf -v applescripttext 'display notification %s with title %s' "$message" "$subject"
            if osascript -e "$applescripttext"; then 
              return 0
            else
              errors+=("osascript: $?")
            fi
          else
            logger="syslog -s -l INFO"
            nix_notify
          fi
          ;;
      esac
      ;;
  esac
  declare -a meta_message
  meta_message+=("some attempts to notify the user may have failed")
  meta_message+=("original subject: $subject original message: $message errors: ${errors[@]}")
  se "${meta_message[@]}"
  $logger "${meta_message[@]}"
}

function osutil_load() {
  if [ -z "$osutil_in_env" ] || $osutil_in_env; then
    if [ -f "$OSUTIL" ]; then
      source "$OSUTIL"
      return 0
    else
      se "OS not properly detected or \$OSUTIL not found."
      return 1
    fi
  fi
}
osutil_load

alias sall="sbrc; sglobals; sutil; sosutil"

# initialized the helper library for the package installer
# for whatever the detected os environment is; good for interactive
# use below for scripts
function i() {
  source $D/installutil.sh
  return $?
}

function install_util_load() {
  if undefined "sai"; then 
    source "$D/installutil.sh"
  fi
  i
  return $?
}
alias siu="source $D/installutil.sh"
alias viu="vim $D/installutil.sh && siu"

# so we dont load all that nonsense into the env, but the super
# frequently used ones remain readily available
if undefined "sai"; then
  sai() {
    unset -f sai sas sauu; i; sai "$@"
  }
  sas() {
    unset -f sai sas sauu; i; sas "$@"
  }
  sauu() { 
    unset -f sai sas sauu; i; sauu "$@"
  }
fi



# for other files to avoid re-sourcing
UTILSH=true
