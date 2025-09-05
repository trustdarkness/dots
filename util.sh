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


###############################################################################
#### 1. Global errors, UI els, external function loads, and helper functions
###############################################################################

# for consistency and readability, use globals for error codes
# loosely modeled on linux's /usr/include/asm-generic/errno.h
declare -i EX_DATAERR=65 # data format error
declare -i EINVAL=22 # nvalid argument

# for cli UI consistency, readability and ease of change
declare ARROW=$'\u27f6'

declare -F is_function > /dev/null 2>&1 || is_function() {
  ( declare -F "${1:-}" > /dev/null 2>&1 && return 0 ) || return 1
}
export -f is_function

shopt -s expand_aliases
function undeclared() {
  if ! declare -p "${1:-}" > /dev/null 2>&1; then
    return 0
  fi
  return 1
}
if undeclared path_append; then
  source "$D/pathlib.sh"
fi
_setup_path
path_append "$D"

# required by colnum
if ! is_function exists; then
  source "$D/existence.sh" # ssource if debug
fi

# required by function_finder; bytes_converter
source "$D/filesystemarrayutil.sh"
source "$D/user_prompts.sh" # required by dgrep

# initialized the helper library for the package installer
# for whatever the detected os environment is; good for interactive
# use below for scripts
alias i='source "$D/installutil.sh"'

# TODO: deprecate
alias install_util_load=i

alias viu="vim $D/installutil.sh && siu"

# A slightly more convenient and less tedious way to print
# to stderr, canonical in existence # TODO, check namerefs on resource
if undeclared "se"; then
  # Args:
  #  -u - do not add a newline when printing, similar to one of the use
  #       cases for printf vs echo.
  #
  #  Otherwise, se echoes to stderr anything it recieves, and If theres
  #  no newline in the input, it is added. if there are substitutions
  #  for printf in $1, then $1 is treated as format string and
  #  $:2 are treated as substitutions.  se replaces any literal '-' with
  # '\x2D', the hex char code for '-' otherwise there are cases where
  # printf will try to interpret these as flags.
  # No explicit return code
  function se() {
    local nonewline
    nonewline=false
    color=
    if [[ "${1:-}" == "-u" ]]; then
      nonewline=true
      shift
    fi
    if [[ "${1:-}" =~ "-c=(.*)" ]]; then
      color="${BASH_REMATCH[1]}"
      shift
    fi
    if [[ "$*" == *'%'* ]]; then
      sub="${@:2}"
      # if the provided string contains a '-' in the first column, printf
      # will try to interpret it as a command line flag
      if [ -n "$color" ]; then printf "$color"; fi
      if ! >&2 printf "${1:-/'-'/'\x2D'}" "${sub/'-'/'\x2D'}"; then
        if [ -n "$color" ]; then printf "${RST}"; fi
        return "$EINVAL"
      fi
    else
      if [ -n "$*" ]; then # like echo, sometimes se is used just to emit \n
        if [ -n "$color" ]; then printf "$color"; fi
        if ! >&2 printf "${@/'-'/'\x2D' }"; then
          if [ -n "$color" ]; then printf "${RST}"; fi
          return 1
        fi
      fi
    fi
    if untru "$nonewline"; then
      if [[ "$*" != *$'\n'* ]]; then # match on the ANSI Cstring
        if [ -n "$color" ]; then printf "$color"; fi
        if ! >&2 printf '\n'; then
          if [ -n "$color" ]; then printf "${RST}"; fi
          return 1
        fi
      fi
    fi
  }
fi

function colnum() {
  help() {
    echo "echos the column number of substring in string if found"
    echo "returns 0 if successful, 255 if substring not found, 1 otherwise"
    return 0
  }
  substring="${1:-}"
  string="${2:-}"
  if empty "$substring" || empty "$string"; then
    help 1
  fi
  rest=${string#*"$substring"}
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

function tac() {
  tail -r $@
}

# depends: filesystemarrayutil.sh in_array
function bytes_converter() {
  # adapted from https://gist.github.com/sanjeevtripurari/6a7dbcda15ae5dec7b56
  valid_tos=( "KB" "MB" "GB" "TB" "PB" )
  converterusage() {
    cat <<-EOF
bytes_converter - takes a numeric bytes value and converts to human friendly formats

Example:
  $ bytes_converter 2094196 MB

Second argument must be one of ${valid_tos[@]}
EOF
  }
  if [ $# -lt 2 ] || [[ "${1:-}" =~ \-(h|?) ]]; then
    converterusage
    return 1
  fi
  bytes="${1:-}"
  to="${2:-}"

  if ! in_array "$to" "valid_tos"; then
    converterusage
    return 1
  fi
  # echo "scale=4; $n1/($n2)" |bc
  k_ilo=1024;
  m_ega=$k_ilo*$k_ilo;
  g_iga=$m_ega*$k_ilo;
  t_era=$g_iga*$k_ilo;
  p_eta=$t_era*$k_ilo;
  case $to in
    KB) let pn=$k_ilo;;
    MB) let pn=$m_ega;;
    GB) let pn=$g_iga;;
    TB) let pn=$t_era;;
    PB) let pn=$p_eta;;
  esac
  converted=$(echo "scale=4; $bytes/($pn)" |bc)
  echo "$converted $to"
}

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

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

function errcolor()(set -o pipefail;"$@" 2>&1>&3|sed $'s,.*,\e[31m&\e[m,'>&2)3>&1

# Arg1 is needle, Arg2 is haystack
# returns 0 if haystack contains needle, retval from grep otherwise
# TODO: deprecate in favor of form grep -q "$needle" <<< "$haystack"
function string_contains() {
  echo "${@:2}"| grep -Eqi "${1:-}"
  return $?
}
alias stringContains="string_contains"

function startswith() {
  local query="${2:-}"
  local starts_with="${1:-}"
  if [[ "$query" =~ ^$starts_with.* ]]; then
    return 0
  fi
  return 1
}

 # super sudo, enables sudo like behavior with bash functions
function ssudo () {
  [[ "$(type -t "$1")" == "function" ]] &&
    ARGS="$@" && sudo -E bash -l -c "$(declare -f $1); \"$ARGS\""
}
alias ssudo="ssudo "

function is_alpha_char() {
  local string="${1:-}"
  if [ -n "$string" ] && [[ "$string" =~  [A-z] ]]; then
    return 0
  fi
  return 1
}

# end 1. Globals

###############################################################################
#### 2. Date and Time global and helper funcs
###############################################################################

# FSTS moved to .bash_profile
LAST_DATEFMT="%a %b %e %k:%M" # used by the "last" command
PSTSFMT="%a %b %e %T %Y" # date given by (among others) ps -p$pid -o'lstart' ex: Thu Dec 26 21:17:01 2024
USCLOCKTIMEFMT="%k:%M %p"

_fsts_gnu_readable() {
  echo "${1:0:8} ${1:9:2}:${1:10:2}:${1:11:2}"
}

function is_fsts() {
  fsts_to_unixtime $@ > /dev/null 2>&1
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
    date -d "$(_fsts_gnu_readable "${1:-}")" +"%s"
  fi
  return $?
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

# end 2. date and time

###############################################################################
#### 3. int testing and comparison with lazy defaults for empty vars
###############################################################################

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
# if term2 is not an int or param 3 is set to true, indicating both args
# must be ints, return 2
function gt() {
  term1="${1:-}"
  term2="${2:-}"
  mustbeint="${3:-false}"
  if is_int ${term1}; then
    if is_int ${term2}; then
      if [ ${term1} -gt ${term2} ]; then
        return 0
      else
        return 1
      fi
    else
      return 2
    fi
  elif "$mustbeint"; then
    return 2
  elif [[ "${term1}" == "" ]]; then
    return 1
  fi
}

# Args: first term we hope is less than the second.
# returns 0 if it is, 1 otherwise. if first term is "", return 1
# if term2 is not an int or param 3 is set to true, indicating both args
# must be ints, return 2
function lt() {
  term1="${1:-}"
  term2="${2:-}"
  mustbeint="${3:-false}"
  if is_int ${term1}; then
    if is_int ${term2}; then
      if [ ${term1} -lt ${term2} ]; then
        return 0
      else
        return 1
      fi
    else
      return 2
    fi
  elif "$mustbeint"; then
    return 2
  elif [[ "${term1}" == "" ]]; then
    return 1
  fi
}

# Args: first term we hope is less than the second.
# returns 0 if it is, 1 otherwise. if first term is "", return 1
# if term2 is not an int or param 3 is set to true, indicating both args
# must be ints, return 2
function le() {
  term1="${1:-}"
  term2="${2:-}"
  mustbeint="${3:-false}"
  if is_int ${term1}; then
    if is_int ${term2}; then
      if [ ${term1} -le ${term2} ]; then
        return 0
      else
        return 1
      fi
    else
     return 2
    fi
  elif "$mustbeint"; then
    return 2
  elif [[ "${term1}" == "" ]]; then
    return 1
  fi
}

# Takes 3 ints as args, returns 0 if
# Arg2 > Arg1 > Arg3 or Arg2 < Arg1 < Arg3
# returns 1 otherwise
function in_between_exclusive() { # TODO: make sure assumptions handle negatives
  between="${1:-}"
  t1="${2:-}"
  t2="${3:-}"
  mustbeint=true
  if  [[ "$t1" == "-1" ]]; then
    ((between++))
    t1=0
    ((t2++))
  fi
  if gt ${between} ${t1} "$mustbeint"; then
    if lt ${between} ${t2} "$mustbeint"; then
      return 0
    fi
  fi
  return 1
}

# Takes 3 ints as args, returns 0 if
# Arg2 => Arg1 => Arg3 or Arg2 <= Arg1 <= Arg3
# returns 1 otherwise
function in_between_inclusive() { # TODO: make sure assumptions handle negatives
  between="${1:-}"
  t1="${2:-}"
  t2="${3:-}"
  mustbeint=true
  if  [[ "$t1" == "-1" ]]; then
    ((between++))
    t1=0
    ((t2++))
  fi
  if gt ${between} ${t1} "$mustbeint" || [[ $between == $t1 ]]; then
    if lt ${between} ${t2} "$mustbeint" || [[ $between == $t2 ]]; then
      return 0
    fi
  fi
  return 1
}

function in_between() {
  between="${1:-}"
  t1="${2:-}"
  t2="${3:-}"
  exclusive="${4:-true}"
  if "${exclusive}"; then
    in_between_exclusive "${between}" "${t1}" "${t2}"; return $?;
  else
    in_between_inclusive "${between}" "${t1}" "${t2}"; return $?;
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

# end 3. int handling

###############################################################################
#### 4. OS detection and working environment setup
###############################################################################

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

# Returns the architecture of the running system
function system_arch() {
  uname -m
}

function what_os() {
  if is_mac; then echo "MacOS"; return 0; fi
  if is_linux; then echo 'GNU/Linux'; return 0; fi
}

function setup_working_env() {
  # this can be used for an application to setup cache, data, state, log
  # dirs, but when used with no arguments, sets those up for interactive
  # use of functions available by use of the dots repo
  local app="${1:-com.trustdarkness.dots}"
  local targets=( config cachedir statedir datadir logdir )
  local homes=( CONFIGHOME CACHEHOME STATEHOME DATAHOME )
  case $(what_os) in
    'GNU/Linux')
      { [ -n "$XDG_CONFIG_HOME" ] && CONFIGHOME="$XDG_CONFIG_HOME"; } || \
        CONFIGHOME="$HOME/.config"
      { [ -n "$XDG_CACHE_HOME" ] && CACHEHOME="$XDG_CACHE_HOME"; } || \
        CACHEHOME="$HOME/.local/cache"
      { [ -n "$XDG_STATE_HOME" ] && STATEHOME="$XDG_STATE_HOME"; } || \
        STATEHOME="$HOME/.local/state"
      { [ -n "$XDG_DATA_HOME" ] && DATAHOME="$XDG_DATA_HOME"; } || \
        DATAHOME="$HOME/.local/share"

      if [[ "$app" == "com.trustdarkness.dots" ]]; then
        OSUTIL="$D/linuxutil.sh"
        alias sosutil='source "$D/linuxutil.sh"'
        alias vosutil="vim $D/linuxutil.sh && sosutil"
      fi
      ;;
    "MacOS")
      # using python's platformdirs for home locations
      CONFIGHOME="$HOME/Library/Application Support"
      CACHEHOME="$HOME/Library/Caches"
      STATEHOME="$CONFIGHOME"
      DATAHOME="$CONFIGHOME"
      LOGSHOME="$HOME/Library/Logs"

      if [[ "$app" == "com.trustdarkness.dots" ]]; then
        OSUTIL="$D/macutil.sh"
        alias sosutil='source "$D/macutil.sh"'
        alias vosutil="vim $D/macutil.sh && vosutil"
      fi
      ;;
  esac
  if [[ "$app" == "com.trustdarkness.dots" ]]; then
    # trying to cover ground or inherit, rather, for code that's
    # already out there, there's a bit of redundancy (see below)
    CONFIG="$CONFIGHOME/$app"
    CACHE="$CACHEHOME/$app"
    STATEDIR="$STATEHOME/$app"
    DATADIR="$DATAHOME/$app"
    if [[ $(what_os) == 'GNU/Linux' ]]; then
      LOGDIR="$DATADIR/logs"
    fi
    # redundancy:
    CONFIGDIR="$CONFIG"
    CACHEDIR="$CACHE"
  else
    workingdirs=()
    se "working dirs for $app setup as..."
    local index=0
    for target in "${targets[@]}"; do
      if [[ "$target" == "logdir" ]]; then
        case $(what_os) in
          'GNU/Linux')
            declare -n datadir="${app}_datadir"
            declare "${app}_logdir"="$datadir/logs"
            workingdirs+=( "$datadir/logs" )
            se "  ${app}_logdir=\"$datadir/logs\""
            ;;
          'MacOS')
            declare "${app}_logdir"="$LOGSHOME/$app"
            workingdirs+=( "$LOGSHOME/logs" )
            se "  ${app}_logdir=\"$LOGSHOME/$app\""
            ;;
        esac
      else
        declare -n home=${homes[$index]}
        declare "${app}_${target}"="$home/$app"
        workingdirs+=( "$home/$app" )
        se "  ${app}_${target}=\"$home/$app\""
      fi
      ((index++))
    done

    declare -gn "${app}_workingdirs"=workingdirs
    se
    se "These directories have not been created yet, to create them all"
    se "now, run:"
    se "for dir in \"\${${app}_workingdirs[@]}; do mkdir -p \"\$dir\"; done"
    se
    se "or make sure to makedir -p \$LOGDIR, etc before trying to use each"
  fi
}
setup_working_env

sosutil

# end 4. os detect and env setup

###############################################################################
#### 5. Logging
###############################################################################

mkdir -p "$LOGDIR"

# Templates for colored stderr messages
printf -v E "%s[%s]" $ERR "ERROR"
printf -v W "%s[%s]" $WRN "WARN"
printf -v I "%s[%s]" $INF "INFO"
printf -v B "%s[%s]" $DBG "DEBUG"

# implementing log levels selectively tweaking for simplicity and to avoid
# namespace collisions, i.e. with the info command
alias err='_log "$E" "$LINENO"'
alias warn='_log "$W" "$LINENO"'
alias debug='_log "$B" "$LINENO"'
alias inform='_log "$I" "$LINENO"'

LOG_LEVELS=( ERROR WARN INFO DEBUG )

# Given a log level name (as above), return
# a numeric value
# 1 - ERROR
# 2 - WARN
# 3 - INFO
# 4 - DEBUG
_get_log_level() {
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
_striplevel() {
  echo "${1:-}"|sed 's/\x1B\[[0-9;]*[JKmsu]//g'|tr -d '[' |tr -d ']'
}

# based on the numeric log level of this log message
# and the threshold set by the current user, function, script
# do we echo or just log?  If threshold set to WARN, it
# means we echo WARN and ERROR, log everything
_to_echo() {
  this_log=$(_get_log_level "${1:-}")
  threshold=$(_get_log_level "${2:-}")
  if le "$this_log" "$threshold"; then
    return 0
  fi
  return 1
}

# return something resembling user@term - terminfo
# for iterm, terminfo will be the profile name unless Default
# then, and other local termainls, TERM_SESSION_ID
# for ssh, this will be user@host - tty
_user_term_info() {
  local uterm
  local uterminfo
  if [ -n "$SSH_CLIENT" ]; then
    uterm=$(
      [[ "${SSH_CLIENT}" =~ ([!-~]+)[[:space:]] ]] &&
      echo "${BASH_REMATCH[1]}"
    ) || uterm="$SSH_CLIENT" # just in case
    uterminfo="$SSH_TTY"
  elif [ -n "$TERM_PROGRAM" ]; then
    uterm="$TERM_PROGRAM"
    if [ -n "$ITERM_PROFILE" ] && [[ "$ITERM_PROFILE" != "Default" ]]; then
      uterminfo="$ITERM_PROFILE"
    else
      uterminfo="$TERM_SESSION_ID"
    fi
  fi
  printf "%s@%s:%s\n" "$USER" "$uterm" "$uterminfo"
  return $?
}

#      TIMESTAMP [FUNCTION] [LEVEL] PID FILENAME:LINENO
LOGFMT="%20s [%s] %s %s %s"
#         [FUNCTION] [LEVEL] FILENAME:LINENO
SCREENFMT="[%s] %s %s"

# Log to both stderr and a file (see above).  Should be called using
# wrapper functions above, not directly
_log() {
  local lineno
  local funcname
  local ts=$(fsts)
  local pid="$$"
  srcp="${BASH_SOURCE[1]}"
  src=$(basename "$srcp")
  local level="$1"
  local message
  shift
  if [ -z "$LEVEL" ]; then
    local LEVEL=WARN
  fi
  if [[ $(trap) =~ .*err\w\$\{e\[(\$\?|[0-255])\]\}.* ]]; then
    se "unsetting RETURN trap"
    trap RETURN
  fi
  # we opportunistically get the lineno if we can
  if is_int "$1"; then
    err_in_func="$1"
    shift
  fi
  if [ $# -gt 1 ]; then
    sub="${@:2}"
    printf -v message "${message}${1:-/'-'/'\x2D'}" "${sub/'-'/'\x2D'}"
  else
    message="${message}${@/'-'/'\x2D'}"
  fi
  if [ -z "$LOGFILE" ]; then
    if [[ "$srcp" == "environment" ]]; then
      LOGFILE="$LOGDIR/util.sh.log"
    else
      LOGFILE="$LOGDIR/$src.log"
    fi
  fi

  funcname="${FUNCNAME[1]}"
  if [ -n "$funcname" ]; then
    if [ -n "$err_in_func" ]; then
      if [[ "$srcp" != main ]] && [[ "${FUNCNAME[*]}" != *'lineno_in_func_in_file'* ]]; then
        #err_line=$(lineno_in_func_in_file -l "$err_in_func" -F "$funcname" -f "$srcp") &
        #child=$!
        #( sleep 2 && kill $child > /dev/null 2>&1 ) &
        #wait $child
        is_int "$err_line" || err_line=$err_in_func
        src+=":$err_line";

      fi
    fi

  # otherwise, we were called from top level scope of a file other
  # than this or invoked directly from the terminal
  else
    funcname="${FUNCNAME[$findex-1]} invoked from global"
    if [[ "${BASH_SOURCE[0]}" == "${BASH_SOURCE[1]}" ]] || [[ "${#BASH_SOURCE[@]}" == 1 ]]; then
      # we don't want the _log function to silently die under any circumstance
      src=$(_user_term_info) || src="$USER@$SHELL"
    fi
  fi
  this_level=$(_striplevel "$level")
  if [[ "$this_level" == 'DEBUG' ]]; then
    message="$(_prvars) $message"
  fi
  printf -v log_line_leader "$LOGFMT" "$ts" "$funcname" "$level" "pid: ${pid}" "$src"
  printf -v screen_line_leader "$SCREENFMT" "$funcname" "$level" "$src"
  (

    if _to_echo "$this_level" "$LEVEL"; then
      #exec 3>&1
      se "$screen_line_leader $message${RST}"
      # remove coloring when going to logfile
      echo "$log_line_leader $message${RST}" 2>&1 | sed 's/\x1B\[[0-9;]*[JKmsu]//g' >> "$LOGFILE"
    else
      echo "$line_leader $message${RST}" | sed 's/\x1B\[[0-9;]*[JKmsu]//g' >> "$LOGFILE"
    fi
  )
  return 0
}

################# helper functions for catching and printing
# errors with less boilerplate (though possibly making it
# slightly more arcane).  an experiment

# print status, takes a return code
_prs() {
  s=$1
  printf "${STAT}\$?:$RST %d " "$s"
}

# print variables, takes either a list of variable names
# (the strings, not the vars themselves) or looks in a
# global array ${logvars[@]} for same
_prvars() {
  if [ $# -gt 0 ]; then
    for arg in "$@"; do
      logvars+=( "$arg" )
    done
  fi
  for varname in "${logvars[@]}"; do
    n=$varname
    v="${!n}"
    # this should gracefully handle declare -a
    # TODO: handle declare -A
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
_prcao() {
  c="${1:-}"
  a="${2:-}"
  o=$(echo "${3:-}"|xargs)
  e=$(echo "${4:-}"|xargs)
  printf "${CMD}cmd:$RST %s ${CMD}args:$RST %s ${CMD}stdout:$RST %s ${CMD}stderr:$RST %s " "$c" "$a" "$o" "$e"
}

# end 5. logging

###############################################################################
#### 6. Progress bar, spinners, and associated setup, teardown, helpers
###############################################################################

# simple / generic progress bar
# Args: finished, total, message
# where total is the number of steps until the task is complete
# finished is how many steps we've finished until now
# message is a message to print to the side of the progress bar while continue
# to use, first run progress_init outside your work loop, then call
# progress from inside the loop, moving finished closer to total with
# each loop iteration (hopefully)
declare -x BAR_SIZE="##################"
declare -x CLEAR_LINE="\\033[K"
progress() {
  # heavily cribbed from
  # https://github.com/lnfnunes/bash-progress-indicator/blob/master/progress.sh
  finished="${1:-}"
  total="${2:-}"
  message="${3:-}"
  local MAX_STEPS=$total
  local MAX_BAR_SIZE="${#BAR_SIZE}"
  perc=$(($finished * 100 / MAX_STEPS))
  percBar=$((perc * MAX_BAR_SIZE / 100))
  echo -ne "\\r$INF[${BAR_SIZE:0:percBar}] $RST$perc %  $message $finished / $total $CLEAR_LINE"
}

# prints the first line of the status bar with echo -ne '\\r'
# as long as you don't print anything else, the bar will stay
# put and rewrite itself.
progress-init() {
  echo -ne "\\r[${BAR_SIZE:0:0}] 0 %$CLEAR_LINE"
}

spinner-start() {
  set +m
  { spin & } 2>/dev/null
  spinner_pid=$!
}

spinner-stop() {
  { kill -9 $spinner_pid && wait; } 2>/dev/null
  set -m
  echo -en "\033[2K\r"
}

spin() {
  while : ; do for X in '┤' '┘' '┴' '└' '├' '┌' '┬' '┐' ; do echo -en "\b$X" ; sleep 0.1 ; done ; done
}

# end 6. progress and spin

###############################################################################
#### 7. Introspect and search code and functions
###############################################################################

# search code in the $D directory, this repo in other words
# depends user_prompts.sh confirm_yes
dgrep() {
  usage() {
    cat <<-'EOF'
dgrep - Perform a shallow grep of shared utilities and scripts in the
  environment "$D" directory and/or additional important dirs for
  trustdarkness shell code.

Example:
  $ dgrep -p -A4 -B3 -E nameless_resume202[0-4].(pdf|doc)

The above example would search the $D directory in the shell's env for any
file which contains the text "nameeless_resume2024.pdf" or
"nameless_resume2020.doc" as examples.  This is not a filename search, but
a text search of any documents in the specified directory.  In the above
example, symlinks will be followed using pcre2grep as our search command.
Any results will show 4 lines after the match and 3 lines before (-A4 -B3
which will be forwarded to pcre2grep).  This will use extended regex syntax
(because of the -E flag which allows the OR | in parens to match doc or
pdf, per example).  Explanation of flags handled by dgrep without forwarding
to the underlying grep are below.

Args:
  -p - follow symlinks, using pcre2grep, if available
  --ignore=/path/to/ignore - ignore a subdirectory within $D or additional
       provided directories.  The = pattern must be used, --ignore may
       be used multiple times to specify more than one directory.  Will
       accept and parse regex patterns.
  --filenames-only - only return the filneames matched, not the matched
       text.
  --addl-dirs=/path/to/dir - provide additional dirs to grep looking for
       provided pattern in files in those dirs.  This option must use the
       = no spaces syntax.  Regex patterns ok.  --addl-dirs can be used
       multiple times to add multiple additional directories.
  -D for this search, use the provided directory in place of whatever D
       is set to in the shell env.  Can be specified using -D /path/to/D
       or -D=/path/to/D.  If = present, don't use spaces.  For more than one
       dir, use --addl-dirs, if -D is specified more than once, the last
       one specified on the command line input will replace any previously
       provided.  Regex patterns can be specified using the = pattern.
  --print-command - print the commands being run as they are run, this is
       intended to assist troubleshooting difficult or non-responsive queries.
       Setting LEVEL=INFO in the shell will enable inform level logging to
       console and the logfile at $LOGFILE and will also result in underlying
       commands being provided in both locations.
  --nocolor - do not colorize results for the terminal, should be used when
       called by other scripts.
  --help, -h, -? - print this text

  Any other options starting with - or -- will be forwarded to the underlying
  grep (which may be grep in path or pcre2grep depending on selected options).

EOF
  }
  # { shopt -p expand_aliases > /dev/null 2>&1 && printf "$INF%s$RST" '* '; } || printf "$ERR%s$RST" '* ';
  grepargs=()

  # consider making this global
  binfinder() {
    if [[ "$(type -t "${1:-}")" != "file" ]]; then
      which "${1:-}"; return $?
    else
      type -p "${1:-}"; return $?
    fi
  }
  grep="$(binfinder grep)"; debug "before opt parsing grep is $grep";
  onlyfiles=false
  print_command=false
  nocolor=false
  addl_dirs=()
  ignore= ; unset ignore; ignore=()
  while [[ "${1:-}" == "-"* ]]; do
    inform "${1:-}"
    if [[ "${1:-}" =~ \-p ]]; then
      if ! grep="$(binfinder pcre2grep)"; then
        grep="$(binfinder grep)"
        warn "pcre2grep not installed; using $grep."
      fi
      shift
    elif [[ "${1:-}" =~ \-\-filenames\-only ]]; then
      onlyfiles=true
      shift
    elif [[ "${1:-}" =~ \-\-ignore=(.*) ]]; then
      ignore+=("${BASH_REMATCH[1]}")
      shift
    elif [[ "${1:-}" =~ \-\-addl\-dirs=(.*) ]]; then
      potential="${BASH_REMATCH[1]}"
      if [ -d "$potential" ]; then
        addl_dirs+=( $potential )
      fi
      shift
    elif [[ "${1:-}" =~ \-D$ ]]; then
      local D="${2:-}"
      shift
      shift
    elif [[ "${1:-}" =~ \-D=(.*) ]]; then
      local D="${BASH_REMATCH[1]}"
      shift
    elif [[ "${1:-}" =~ \-\-print_command ]]; then
      print_command=true
      shift
    elif [[ "${1:-}" =~ \-\-nocolor ]]; then
      nocolor=true
      shift
    elif [[ "${1:-}" =~ \-h|\-\-help|\-? ]]; then
      usage
      return 0
    else
      grepargs+=( "${1:-}" )
      shift
    fi
  done
  debug "after opt parsing grep is $grep"
  sterm="$@"
  if [ -z "$D" ]; then
    if confirm_yes "D not in env, do you want to search PATH?"; then
      #TODO
      :
    fi
  fi
  total_found=0
  file_searcher() {
    # if there are ever more exceptions, make this more visible
    { [ -f "$item" ] && [[ "$item" != *LICENSE ]] && file=$item; } || return
    if tru "$print_command" || [[ "$LEVEL" == "INFO"* ]]; then
      { [[ "$LEVEL" == "INFO"* ]] && pcc="eval inform"; } || pcc="printf";
      $pcc "$ARROW searching with %s -n " "$grep"
      $pcc "%s " "${grepargs[@]}"
      $pcc "%s %s" "$sterm" "$file"
      $pcc "\n"
    fi
    found=$($grep -n ${grepargs[@]} "$sterm" "$file"); ret=$?||true
    if [ $ret -eq 0 ]; then
      bn=$(basename "$file")
      if [[ "${ignore[*]}" != *"$bn"* ]]; then
        echo "$file"
        if ! $onlyfiles; then
          while read -r line ; do
            if tru "$nocolor"; then
              echo "$line"
            else
              echo "  ${line/$sterm/${GREEN}${sterm}${RST}}"
            fi
          done < <(echo "$found")
          echo
          ((total_found+=$(echo "$found"|wc -l|xargs)))
        fi
      fi
    fi
  }
  for item in "$D"/*; do
    file_searcher|| true # this is a printer/accumulator, exit code moot
  done
  if [[ "${#addl_dirs[@]}" -gt 0 ]]; then
    for dir in "${addl_dirs[@]}"; do
      for item in "$dir"/*; do
        file_searcher || true
      done
    done
  fi
  if [ $total_found -gt 0 ]; then
    return 0
  fi
  return 1
}

function is_bash_script() {
  script="${1:-}"
  [ -n "$script" ] || { err "provide a filename"; return 1; }
  if [ -f "$script" ]; then
    bash_shebang_validator "$script"
    return $?
  else
    err "$script does not seem to be a file, try full path?"
    return 2
  fi
}

VALID_POSIXPATH_EL_CHARS='\w\-. '
VALID_POSIXPATHS_REGEX="$(printf '[\/*%s]+' "$VALID_POSIXPATH_EL_CHARS")"
BASH_FUNCTION_WITH_NAME_PCREREGEX='(function %s *\(\) +{|%s *\(\) +{|%s +{)'

function_regex() {
  printf -v "${1:-}" "$BASH_FUNCTION_WITH_NAME_PCREREGEX" "${2:-}" "${2:-}" "${2:-}"
}

function_substring_regex() {
  regex_name="${1:-}"
  substring_to_search="${2:-}"
  printf -v simple_substring_regex '.*%s.*' "$substring_to_search"
  function_regex "$regex_name" "$simple_substring_regex"
}

function_regex BASH_FUNCTION_PCREREGEX "[A-z0-9_]+"
_BWVR='^bash[_-]{0,1}(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|'
_BWVR+='[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*'
_BWVR+='[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$'
BASH_WITH_VERSION_REGEX="$_BWVR"

bash_shebang_validator() {
  _env_ok() {
    to_test="${1:-}"
    { pcre2grep "\#\!$VALID_POSIXPATHS_REGEX" > /dev/null 2>&1 < <(echo "$to_test"); ret=$?; } ||
      { "$BASH_COMMAND failed with ret $ret"; return 9; }
    if [ $ret -eq 0 ]; then
      # this is now an array but we bastardized the functionality to pop
      # off the first word and so we'll just treat it like variable
      shebangcmd="${to_test%% *}"
      bangcmd="${shebangcmd:2}"
      if ! [ -x "$bangcmd" ] || ! [ -s "$bangcmd" ]; then
        return 2
      fi
      if [[ "$bangcmd" != *'env' ]]; then
        return 3
      fi
    fi
    if [ -n "$bangcmd" ]; then
      testout=$($bangcmd "VARNAME=value" "bash" "-c" 'echo $VARNAME'); ret=$?
      if [[ "$testout" == "value" ]]; then return 0; fi
      # if the test succeeds, we should never reach the next line
      error "expected first part of shebang with spaces to be env, but got $bangcmd"
      return 6
    fi
    return 4
  }
  bash_script="${1:-}"
  she_bang=$(head -n 1 "${bash_script}") || \
    { se "failed to head $bash_script"; return 6; }
  if [[ "$she_bang" == *' '* ]]; then
    # valid shebangs for bash scripts with a space should call env
    # to later call bash; split on space
    IFS=' ' read -r -a shebang_components <<< "${she_bang}"
    sheenv="${shebang_components[0]}"
    bashend="${shebang_components[-1]}"
    _env_ok "$sheenv" || {
      w="Shebang contains a space, which means the first term should point to env ";
      w+="but instead points to $sheenv.";
      warn "$w";
      return 7;
    }
    # echo "bashend: $bashend"
  else
    bashend="$she_bang"
  fi
  if [[ "$bashend" == *'bash' ]]; then
    return 0
  else
    [[ "$bashend" =~ $BASH_WITH_VERSION_REGEX ]] && return 0
    error "bash does not appear to be in shebang $she_bang of $bash_script"
    return 5
  fi
}

# given a filename, return an alphanumeric (plus underscores) version
# with no dots, suitable for variable names
function _vslugify() {
  name="${1:-}"
  ext=
  unset slugified # if this is needed, should be copied into the local namespace
  declare -gA slugified
  if grep -q "/" <<< "$name"; then
    dn=$(dirname "$name")
    name=$(basename "$name")
  fi
  old_name="$name"
  # if [[ "${name}" =~ ^[\w,\s-]+[\.[A-Za-z]]+ ]]; then
  #   ext="${name##*.}"
  #   name="${name%.*}"
  # fi
  slugified_name=$(echo "$name"| sed 's/^\./_/g'| sed 's/ /_/g' |sed 's/[^[:alnum:]\t]//g')
  if [ -n "$ext" ]; then slugified_name="$slugified_name.$ext"; fi
  slugified["$slugified_name"]="$old_name"
  echo "$slugified_name"
  return 0
}

# depends
# - filesystemarrayutil.sh
#  * array_to_set
function_finder() {
  l=$((LINENO-1))
  usage() {
    cat <<-'EOF'
function_finder - prints functions declared in a bash script

Args:
  -f filename of bash script to search in
  -S search for the function in known dependency locations, ignored
     if -f is also present
  -F (optional) function name to search for, can be specified
     more than once to find multiple functions
  -s <term> search for term in function names
  -c <term> search for term in function contents
  -O use logical OR when both -s and -c are present
  -A use logical AND when both -s and -c are present
  -a dirname to add to standard search parameters. can be used multiple
       times to add multiple additional directories
  -l print line numbers of function declarations
  -L only print the line numbers
  -n include nested functions (false if not speicified)
  -w wide display mode, prints functions in columns instead
     of one per line.  If function bodies are being printed because
     we're searching with -c, this flag will be ignored.
  -d if trustdarkness dpHelpers installed, add relavent paths for
     its shell functions to the search perimeter
  -h print this text
EOF
  } # end usage()

  # declare vars, arrays, and flags, set to default vals for init
  unset ffs
  ffs=()
  oargs=( "$@" ) # really a copy for troubleshooting only
  local pcre2grepopts=('-n' '--null') # do we need this for other greps
  local flinenos=false
  local onlylinenos=false
  declare -ga functions # TODO: remove -g after testing
  functions=()
  local nested=false
  local pager="cat"
  local dpHelpers=false

  # addl info flags... do we need function bodies?
  local F_bodies=false

  # search modes -
  #   - F means func names provided
  #   - f means file provided
  #   - s means func name search term provided
  #   - c means func body search term provided
  #   - d means we have ho filenames and are relying
  #       on dgrep and/or declare
  local Ff_search=false
  local fs_search=false
  local fc_search=false
  local fsc_search=false

  local ds_search=false
  local dc_search=false
  local dsc_search=false
  local dF_search=false
  local dFc_search=false

  # for searching function content, it will be useful to flag
  # c_search's regardless of source
  local sc_search=false
  local c_search=false

  # we'll call dFs out of bounds because the user would be inputting
  # function names and a search term that should be in them.  hopefully
  # they're noticers enough that they'll catch that on their own.
  # likewise dFsc.  hashtag not a noticer

  # var declarations we want to be empty each time
  local Fbody; unset Fbody; Fbody= # only the paranoid survive
  local file; unset file; file=
  declare -a xtradirs
  local xtradirs; unset xtradirs; xtradirs=()
  declare -ga funcs_found # TODO: either remove -g or make it an all-caos
                          # proper global if that's useful
  unset funcs_found
  funcs_found=()

  # containers for error messages
  local em; unset em; em=
  local ef; unset ef; ef=

  # consider whether we should care about existing dgrep opts and if so
  # whether it makes sense to have an option masher
  dgrepopts=("-p" "-c" "-l" "-n" "--filenames-only")

  optspec="lLnf:F:wha:c:s:AO"
  unset OPTIND
  unset optchar
  while getopts "${optspec}" optchar; do
    case "${optchar}" in
      l)
        flinenos=true
        ;;
      L)
        onlylinenos=true
        flinenos=true
        ;;
      n)
        nested=true
        ;;
      f)
        file="${OPTARG}" # TODO: allow providing multiple files as args
        ;;
      F)
        functions+=("${OPTARG}")
        ;;
      w)
        pager="column"
        ;;
      a)
        if [ -d "${OPTARG}" ]; then
          xtradirs+=( "${OPTARG}" )
        else
          warn "${OPTARG} is not a directory.  ignoring."
        fi
        ;;
      c)
        cterm="${OPTARG}"
        ;;
      s)
        sterm="${OPTARG}"
        ;;
      A)
        sc_AND=true
        ;;
      O)
        sc_OR=true
        ;;
      d)
        dpHelpers=true
        ;;
      h)
        usage
        return 0
        ;;
      *)
        usage
        return 1
        ;;
    esac
  done
  shift $(($OPTIND -1))
  local _argc_post=$1 # for debugging purposes only ATM.  Consider doing fuzzy
                      # search on function_name / sterm if trailing positional
                      # args exist
  if [ -n "$_argc_post" ]; then
    warn "found trailing positional arg $_argc_post, did you intend -s or -F?"
    warn "will ignore and try to proceed with remainder of options."
  fi

  # if the user gave us -F $func_names on the command line, lets dedup
  array_to_set "functions"

  # these are designed to be as similar as possible so that likely we can
  # further simplify by putting the grep and opts in vars
  _functions_from_file() {
    # func_name; func_regex; and file are expected to be defined in the
    # calling scope, as is funcs_found  if func_name is empty, sed will noop
    # and funcs_found+=( "$line" ) will fall through naturally.  probably ok
    # if file is empty too, as long as greo can handle that
    while IFS= read -r line; do
      funcdef=$(echo "$line" | sed "s/\($func_name\)\([(].*\)/\1/g")
      [ -n "$funcdef" ] && funcs_found+=( "$funcdef" )
    done < <(pcre2grep ${pcre2grepopts[@]} "$func_regex" "$file"); ret=$?;
    return $ret
  }

  # TODO: test setting grep=(pcre2grep|dgrep), grabbing the appropriate opts
  # and letting empty $file handle itself and eliminate the redundant private
  # function
  _functions_from_dgrep() {
    while IFS= read -r line; do
      funcdef=$(echo "$line" | sed "s/\($func_name\)\([(].*\)/\1/g")
      [ -n "$funcdef" ] && funcs_found+=( "$funcdef" )
    done < <(dgrep ${dgrepopts[@]} "$func_regex"); ret=$?;
    return $ret
  }

  _process_line() {
    line="${1:-}"
    if [[ "$line" == "#"* ]]; then return 2; fi
    if ! $nested && [[ "$line" == " "* ]]; then return 3; fi
    processed=$(echo "$line"|
      sed 's/function //g'| # remove any function keywords
      sed 's/\(\h*\)\h*{//g'|
      sed 's/\(.*\) || //g'|
      sed 's/\#.*//g'|
      sed 's/()//g') # remove parens and brackets
                      # TODO: will need to be updated
                      # if we still want to lazily
                      # support c
    if [ -n "$processed" ]; then echo "$processed"; return 0; fi
    # either there will be processed data or criteria haven't been met
    return 1
  }

  # process any provided file first for function names; lets make sure we
  # sanity check opts and args, we can either search in files or directories
  # but currently not both in the same command
  if [ -f "${file}" ]; then

    #### Error conditions with invalid argument combinations
    if tru "$dpHelpers"; then # error condition bad use of args EINVAL
      em="-f file searches cannot be combined with directory / env searches "
      em+="that utilize \$D and dgrep.  -f and -d not valid together."
    fi

    if [ "${#xtradirs}" -gt 0 ]; then # currently don't support searching
                                      # specific files and dirs in ths same cmd
      em="-a directory searches cannot be added on to -f file searches "
      em+="these should be split into separate commands or a directory should "
      em+="be provided that contains the file and -f should be removed."
    fi

    if [ -n "$em" ]; then
      err "$em"; return $EINVAL;
    fi

    if [ "${#functions[@]}" -gt 0 ]; then
      Ff_search=true # probably unittest these search types
      for func_name in "${functions[@]}"; do
        function_regex func_regex "$func_name"
        _functions_from_file # adds to funcs_found
      done
    else
      # here we get all functions in the file when we're provided a file
      # but no specific function names, we'll filter for sterm and cterm later
      func_regex="$BASH_FUNCTION_PCREREGEX"
      _functions_from_file # adds to funcs_found
    fi

  else # no file can be found to search in, handle error conditions if
       # the user provided a file

    if [ -e "$file" ]; then # we -f above, if that's false, -e means dir or
                            # some non-regular file exists
      ef="received -f $file but $file is not a regular file. "
      ef+="for directory searches, please use -a.  Other special file types "
      ef+="are not supported."

    elif [ -n "$file" ]; then # the user provided -f $file, but its not on
                              # the file system in any way

      ef="received -f $file but could not find $file."

    fi # we have an ef error, or no $file if no match, advance below next err

    if [ -n "$ef" ]; then
      err "$ef"; return 2; # check for file handling error codes and add
                           # here and to globals TODO: mt
    fi # errored and returned ef 2

    ####
    # no files provided, search for funcs using dgrep

    #### Custom, user specified dgrep search perimter expansion (-d)
    if tru "$dpHelpers"; then  # this should turn into a flag specific
                              # to dpHelpers, which is sloppy, but can
                              # perhaps provide a template for a more
                              # generic set of custom user-important dirs
      if ! [ -d "$DPHELPERS" ]; then
        { type -p cddph > /dev/null 2>&1 && cddph; } ||
        { [ -d "$HOME/src/dpHelpers" ] && DPHELPERS="$HOME/src/dpHelpers"; };
      fi
      # we should now have DPHELPERS and lib/bash if its sane; if not
      # throw a warning and move on.
      if [ -d "$DPHELPERS" ] && [ -d "$DPHELPERS/lib/bash" ]; then
        dgrepopts+=( "--addl-dirs=$DPHELPERS/lib/bash" )
      else
        warn "Could not add DPHELPERS to function_finder"
      fi # either we found dphelpers or we warned
    fi # matched means -d

    #### Get any manually added dirs to expand perimeter (-a)
    if [ "${#xtradirs}" -gt 0 ]; then # we already error checked these are real dirs
      for xtradir in "${xtradirs[@]}"; do
        dgrepopts+=("--addl-dirs=\"$xtradir\"");
      done
    fi # matched means -a

    #### Start with user provided function names (-F)
    if [ "${#functions[@]}" -gt 0 ]; then
      dF_search=true # just bookkeeping at this point
      for func_name in "${functions[@]}"; do
        function_regex func_regex "$func_name"
        _functions_from_dgrep # adds to funcs_found
      done
    fi # matched means -F

    #### Whether or not -F, we may have search terms for the func name (-s) or
    #### search terms for the function body (-c) using OR (-O) or AND (-A)
    #### note the sc_AND flag is not checked in the code, but its condition
    #### should be implied by what's left after the continues are filtered out
    if [ -n "$sterm" ]; then # TODO: support multiple sterms?
      ds_search=true; s_search=true;
      function_substring_regex func_regex "$sterm"
      _functions_from_dgrep
    fi # matched means -s


    if [ -n "$cterm" ]; then
      dc_search=true; c_search=true;
       # use function body regex for substring search
    fi # matched means -c

  fi # if user provided a file, we did _functions_from_file, if file was bad
     # or no file provided, we handled the errors or did _functions_from_dgrep

  # now in either case, if we found anything, our results array should be
  # populated and we can filter and print.  Below is probably redundant with what's
  # below that, but we did bookkeeping first.  TODO: simplify and cleanup

  # for the moment, this just tells us explicitly what searches are in scope

  if [ -n "$sterm" ] && [ -n "$cterm" ]; then # both s and c, we should have
                                              # sc_OR or sc_AND for this to
                                              # be sane and deliberate
    if [ -z "$sc_AND" ] && [ -z "$sc_OR" ]; then # move this error checking to
                                                 # opt handling
      em="When both -c and -s are provided, either -O (OR) or -A (AND)"
      em+="should be specified so that searches are unambiguous."
      err "$em"; return $EINVAL
    fi
    F_bodies=true
    # record keeping is overzealous and can probably be simplified
    sc_search=true
    # sc_search means either fsc or dsc, depending on whether we have a file
    { [ -f "$file" ] && fsc_search=true; } || dsc_search=true;
  else
    if [ -n "$sterm" ]; then
      s_search=true
      { [ -f "$file" ] && fs_search=true; } || ds_search=true;
    fi
    if [ -n "$cterm" ]; then
      F_bodies=true
      c_search=true
      { [ -f "$file" ] && fc_search=true; } || dc_search=true;
    fi
  fi

  # we'll use the above search type flags to do soe filtering and grab
  # function bodies as we come across functions if needed
  for linefunction in "${funcs_found[@]}"; do
    # line function is a return line from one of our greps, we parse for
    # line number and then process the line to clean it up
    lineno=$(echo "$linefunction" | cut -d":" -f1)
    fline=$(echo "$linefunction" | cut -d":" -f2)

    # if _process_line failed, there may be some criteria not met and
    # we drop the line.  Its not necessarily an error condition.
    # but is necessary to move forward with this iteration of the loop
    if fname=$(_process_line "$fline"); then

      # reset Fbody, just in case
      Fbody=

      # now we are at the level of individual functions and need to check
      # if we have search criteria and whether we need function body
      # text or other info
      if tru "$F_bodies"; then
        Fbody="$(show-function "$fname")"
      fi

      # these will be redundant for ds_searches, but allows us to weave in
      # *c_searches with only the overhead of a redundant grep per func
      if tru "$s_search" || tru "$sc_search"; then

        if ! grep -q "$sterm" <<< "$fname"; then

          # these may be already handled, but for completeness
          if tru "$sc_search" && "$sc_AND"; then continue; fi
          if tru "$s_search" && untru "$c_search"; then continue; fi

          # sterm is specified and not present in the function name
          # so we skip to the next function in the loop.
          if tru "$sc_search" && tru "$sc_OR"; then
            # this is when the sterm did not match, sc_OR is true, meaning
            # user wants the function if the cterm is in the body regardless
            # of whether the sterm is in the name
            if ! grep -q "$cterm" <<< "$Fbody"; then
              # cterm not in body, throw this function out
              continue
            fi
          else
            # sterm does not match and $sc_OR is false, so don't care
            # whether cterm matches, we toss this function
            continue
          fi # end sc OR conditions
        fi # inside this if is if sterm match failed, if it matched, the
           # function will move to lines below

      fi # inside this if, we handled conditions for an s or sc_search that might
         # result in throwing out this function because a condition doesn't match

      # if any type of c_search is present, we need the function body
      if tru "$F_bodies"; then
        # if the cterm isn't in the function body
        if ! grep -q "$cterm" <<< "$Fbody"; then
          # the c_search has failed, if its an AND or only c_search, throw it out
          if { tru "$sc_search" && tru "$sc_AND"; } || tru "$c_search"; then
            continue
          fi
        fi # if we survived here, the cterm is in the function body
      fi # or there is no cterm and no function body

      # so now we should only arrive here for functions that match any
      # of our search conditions, so we print line numbers if requested and
      # function names of any still standing and increment the counter
      if $flinenos; then
        printf "%d " "$lineno"
      fi
      if ! $onlylinenos; then
        printf "%s\n" "$fname"
      fi

      # and if we were asked to search function bodies, we print those as
      # well, though we may want to consider printing a summary of matches
      # like dgrep or allowing the user to specify what they want to see
      # in hopes of avoiding printing big long nasty functions and losing
      # more important stuff as a result.  We still only print linenumbers
      # of function declarations if -L
      if [ -n "$Fbody" ] && untru "$onlylinenos"; then

        # we saud if we're printing function bodies, we'd ignore any pager
        # flags...
        pager=cat
        local IFS=$'\n'
        for line in $Fbody; do # TODO, when -l specified, function body
                               # should also have line numbers.
          # we'll indent just a bit back from the function names and hope
          # the source code is sanely formatted, their indentations should
          # be maintained below ours
          printf "    %s\n" "$line"
        done
      fi # if we had a function body and were not told to only print linenos
         # we printed that function

    fi # if we could process the line, met all criteria, we matched
       # an fname here and processed the inside of the if block

    # the pipe is a noop if pager is cat, if we're only function names and -w
    # the pager is column and we should display wide
  done | $pager # done is for the loop over the funcs_found results array
}


print_function() {
  usage() {
    cat <<-'EOF'
print_function - prints the full function definition for a given name

Args:
  -f filename to find function in (if not specified, will try from env)
  -l include line numbers
  -h print this text

Ex:
 $ print_function -f bash_script.sh my_fancy_function

 function my_fancy_function() {
   echo foo
 }
EOF
  }
  filepath=
  flinenos=false
  optspec="lf:h"
  unset OPTIND
  unset OPTARG
  unset optchar
  while getopts "${optspec}" optchar; do
    case "${optchar}" in
      l)
        flinenos=true
        ;;
      f)
        filepath="$OPTARG"
        [ -f "$filepath" ] || { err "no file at $filepath"; return 2; }
        ;;
      h)
        usage
        return 0
        ;;
      *)
        usage
        return 1
        ;;
    esac
  done
  shift $(($OPTIND - 1))
  function_name="${1:-}"
  if [ $# -gt 1 ]; then
    if [ -f "${2:-}" ]; then
      filepath="${2:-}"
    fi
  elif [ $# -gt 2 ]; then
    usage
  fi
  if [ -z "$filepath" ]; then
    # for convenience
    warn "no filename provided, trying to get $function_name from env"
    declare -pf "$function_name"
    return $?
  fi
  if declare_lineno=$(function_finder -L -f "$filepath" -F "$function_name"|xargs); then

    alllines=$(wc -l "$filepath"| awk '{print$1}')
    tailtop=$((alllines-declare_lineno))
    endline=$((declare_lineno+$(tail -n "$tailtop" "$filepath"|grep -n -m 1 '^}$'| cut -d ":" -f 1)+1))
    if ! is_int "$endline"; then
      error "couldn't parse line number from function_finder"
      return 4
    fi
    if $flinenos; then
      sed -n "$declare_lineno,${endline}{=;p};${endline}q" "$filepath"| sed '{N; s/\n/ /}';
    else
      sed -n "$declare_lineno,${endline}p;${endline}q" "$filepath"
    fi
    echo

  else
    bn=$(basename "$filepath")
    err "couldn't find definition for $function_name at the top level of $bn"
    return 3
  fi
}

# this should work for any function declared in bash files in the dots repo
# depends
# - bash_profile
#  * is_function
load-function() {
  # set -x
  usage() {
    cat <<-'EOF'
    Help!!!
EOF
  }

  load-it() {
    functionname="${1:-}"
    xtradir="${2:-}"
    #set -x
    e=(
      [0]="N\A"
      [1]="function text fails sanity check (multiline regex '(?s)^[A-z0-9_]+\(.*(?=^\}$)')"
      [2]="print_function failed, though we had the filename %s"
      [3]="${functionname} not found in known dependency locations, including: %s"
      [4]='should be unreachable'
      [5]="error evaluating function text %s"
      [6]="error exporting $functionname"
    )
    if [ -n "$xtradir" ]; then
      functionsource="$(function_finder -F "${functionname?}" -S -a "$xtradir")"
    else
      functionsource="$(function_finder -F "${functionname?}" -S)";
    fi
    if [ -z "$functionsource" ]; then
      wherefrom="$D"
      if [ -n "$xtradir" ]; then
        wherefrom+=" and $xtradir"
      fi
      err "${e[3]}" "$wherefrom"
      return 3
    fi
    if functiontext="$(print_function -f "${functionsource?}" "${functionname?}")"; then
      # doublecheck
      if pcre2grep -n -M '(?s)^[A-z0-9_]+\(.*(?=^\}$)' <<< "${functiontext?}"; then
        if tru "$only_print"; then
          echo "${functiontext?}"
        else
          if ! eval "${functiontext?}"; then err ${e[5]} "$functiontext"; return 5; fi
          if ! export -f "${functionname?}"; then err ${e[6]}; return 6; fi
        fi
      else
        err "${e[1]}"
        return 1
      fi
    else
      err "${e[2]}" "${functionsource}"
      return 2
    fi
    err "${e[4]}"
    return 4
  }
  local force=false
  local quiet=false
  local only_print=false
  unset OPTIND
  unset optchar
  optspec="Pfqha:"
  while getopts "${optspec}" optchar; do
    case "${optchar}" in
      f)
      force=true
      ;;
      q)
      quiet=true
      ;;
      a)
      also_search="$OPTARG"
      ;;
      P)
      onlu_print=true
      ;;
      h)
      usage
      return 0
      ;;
    esac
  done
  shift $(($OPTIND - 1))
  fname="${1:-}"

  if is_function "$fname"; then
    if tru $force; then
      unset -f "$fname"
    else
      if untru "$quiet" && untru "$only_print"; then
        echo "$fname already loaded in env as:"
        declare -pf "$fname"
        echo "to explicit force reload, run load-function -f $fname"
        return 0
      fi
      return 0
    fi
  fi
  if ! load-it "$fname" "$also_search"; ret=$?; then
    if [[ $LEVEL == "DEBUG" ]]; then
      ff="$(function_finder -F "$fname" -S)"
      debug "ff: $ff  pf: $(print_function -f "$ff" "$fname")"
    fi
    return $ret;
  fi
  # confirm
  is_function "$fname"
  return $?
}

show-function() {
  load-function -P $@
}

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

BASH_VARNAME_REGEX='[A-z0-9_]+'
BASH_LOCAL_PREFIX='^\h*local\h+([[-][A-z]]*|\h*)\h*'
printf -v BASH_LOCAL_VAR_PCREREGEX '%s%s.*' "$BASH_LOCAL_PREFIX" "$BASH_VARNAME_REGEX"
printf -v BASH_LOCAL_VAR_SED_EXTRACT_NAME2_REGEX '[ \t]*local[ \t]+([[-][A-z] ]*|[ \t]*)\(%s\).*' "$BASH_VARNAME_REGEX"

lineno_in_func_in_file() {
  _usage() {
    echo "lineno_func_in_file \$LINENO \${FUNCNAME} filename_with_decl"
  }
  oargs=( "$@" )
  optspec="l:f:F:?h"
  local lineno
  local function
  local file
  unset OPTIND
  unset optchar
  while getopts "${optspec}" optchar; do
    case "${optchar}" in
      l)
        lineno="${OPTARG}"
        ;;
      f)
        file="${OPTARG}"
        ;;
      F)
        function="${OPTARG}"
        ;;
      h|?)
        # TODO: implement
        echo "help! TODO"
        ;;
    esac
  done
  shift $(($OPTIND - 1))
  if [ -z "$lineno" ] || [ -z "$function" ] || [ -z "$file" ]; then
    while [ $# -gt 0 ]; do
      if is_int "${1:-}"; then
        lineno="${1:-}"; shift
      elif [ -f "${1:-}" ]; then
        file="${1:-}"; shift
      else
        function="${1:-}"
      fi
    done
  fi
  if ! is_int "$lineno" || ! [ -f "$file" ]; then
    err "malformed input: $FUNCNAME ${oargs[@]}"; _usage; return 1
  fi
  local start_of_function=$(function_finder -L -f "$file" -F "$function")
  echo "$((lineno+start_of_function))"
  return $?
}

# end 7. instrospect and search

###############################################################################
#### 8. Internet info helper funcs and git assist
###############################################################################

# https://www.reddit.com/r/sysadmin/comments/t5xnco/curl_wtfismyipcomtext_fast_way_to_find_a/
ip-get-external() {
  curl wtfismyip.com/text
  return $?
}

function wget-download-size() {
  verbose=false
  if [[ "${1:-}" =~ \-v ]]; then verbose=true; shift; fi
  url="${1:-}"
  # not all servers will return headers with content length before sending the
  # file, but the alternative is to download the file to get the size, which
  # we would just as soon prefer to avoid
  response="$(wget --spider --server-response "$url" 2>&1)"
  if $verbose; then >&2 echo "${INF}url: $url response: ${WRN}$response${RST}"; fi
  if [ -n "$response" ]; then
    length="$(echo "$response"|grep -m1 "Length"|awk '{print$2}')"
    if [ -n "$length" ] && is_int "$length"; then
      echo "$length"
      return 0
    fi
  fi
  # if we're here, that didn't work, and we download
  if [ -t 1 ]; then
    se "unable to get length from server headers, downloading file, ctrl-c to cancel"
    spinner-start
  fi
  length="$(xargs wget -qO- | wc -c)"
  if [ -t 1 ]; then
    spinner-stop
    echo "$CLEAR_LINE"
  fi
  if is_int "$length"; then
    echo "$length"
    return 0
  else
    se "an error occurred attempting to download the file and length could not be determined."
    return 1
  fi
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

# because apparently sometimes i can't remember
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

# end 8. internet info

###############################################################################
#### 9. Process info and ps wrappers
###############################################################################

_localize_ps_time() {
  local e=(
    [0]="N\A"
    [1]="mismatched date formats, expecting $PSTSFMT"
    [2]="unreachable code $FUNCNAME $LINENO"
    [3]="getting clocktime failed"
    [4]="converting time to array failed"
    [5]="converting time to FSTSFMT failed"
  )
  local then="${1:-}"

  # split on spaces into arrays
  read -ra now <<< $(date +"$PSTSFMT") #|| err "${e[4]}"; return 4
  read -ra then <<< $(echo "$then") #|| err "${e[4]}"; return 4
  # sanity check, make sure we have the same number of fields

  [ ${#now[@]} -eq ${#then[@]} ] || { err "${e[1]}"; return 1; }
  # which fields should look like Thu Dec 26 21:17:01 2024

  # correct args for mac vs linux
  case $(what_os) in
    MacOS)
      date_args=(-j -f "$PSTSFMT")
      ;;
    "GNU/Linux")
      date_args=(-d)
      ;;
  esac

  # we only need these for one condition, but error handling
  # outside the conditional is cleaner
  mnow=$(date "${date_args[@]}" "${now[*]}" +"%s") || \
    { err "${e[5]}"; return 5; }
  mthen=$(date "${date_args[@]}" "${then[*]}" +"%s") || \
    { err "${e[5]}"; return 5; }

  # we'll use US clock time a couple of places
  clocktime=$(date "${date_args[@]}" "${then[*]}" +"$USCLOCKTIMEFMT") || \
    { err "${e[3]}"; return 3; }

  # case 1: today, in which case, we only want the clock time
  if [[ "${now[@]:0:3}" == "${then[@]:0:3}" ]]; then
    echo "$clocktime"; return 0

  # case 2: within the last week, we want the day and the time
  elif [ $(( $(( mnow - mthen )) / $(( 60 * 60 * 24 )) )) -lt 7 ]; then
    # using the name of the array as a variable is a shortcut to
    # its first item
    echo "$then at $clocktime"; return 0

  # case 3: the process was started in a different year,
  #         display Thu Dec 26 2024 at ct
  elif [ "${now[@]:5:5}" -ne "${then[@]:5:5}" ]; then
    echo "${then[@]:0:3} ${then[@]:-1} at $clocktime"
    return 0

  else
    # case 4: "normal" display Thu Dec 26 at ct
    echo "${then[@]:0:3} at $clocktime"
    return 0
  fi
  # should be unreachable
  err "${e[2]}"; return 2
}

function pidinfo() {
  e=(
    [0]="N/A"
    [1]='ps -p$pid... failed, maybe exited?'
    [2]='could not localize $started'
  )
  local pid="${1:-}"
  # favoring readability over performance
  local name="$(ps -p$pid -ocommand=)"|| { err "${e[1]}"; return 2; }
  if grep -q "/" <<< "$name"; then name=$(basename "$name"); fi
  local cpu="$(ps -p$pid -o'%cpu=')"|| { err "${e[1]}"; return 2; }
  local mem="$(ps -p$pid -o'%mem=')"|| { err "${e[1]}"; return 2; }
  local started="$(ps -p$pid -olstart=)"|| { err "${e[1]}"; return 2; }
  localized=$(_localize_ps_time "$started")|| { warn "${e[2]}"; localize="$started"; }
  IFS='' read -r -d '' pidinfo <<"EOF"
 Process: %s
   PID: %s
   Current CPU: %s %%
   Current RAM: %s %%
   Started at: %s
EOF
  # for field in "$localized"; do pidinfo+=" %s"; done
  printf "$pidinfo" "$pid" "$name" "$cpu" "$mem" "$localized"
  return $?
}

# end 9. process info

###############################################################################
#### 10. env modifications
###############################################################################

function add_permanent_bash_alias_to_bashrc() {
  name="${1:-}"
  to="${2:-}"
  rationale="${3:-}"
  ts=$(fsts)
  if [ -n "$to" ] && ! is_quoted "$to"; then
    to=$(shellquote "$to")
  fi
  mkdir -p "$HOME/.local/bak"
  fs_rationale="$(echo "$rationale"|sed  's/ /_/g')"
  se "existing .bashrc backed up to $HOME/.local/bak/.bashrc.bak.$ts.$fs_rationale"
  # https://stackoverflow.com/questions/5573683/adding-alias-to-end-of-alias-list-in-bashrc-file-using-sed
  tac .bashrc |
  awk "FNR==NR&&/alias/{s=FNR;next}FNR==s{ \$0=\$0\"\nalias $name=\x22$to\x22\n\"}NR>FNR" .bashrc .bashrc > .bashrc.new
  mv "$D/.bashrc" "$HOME/.local/bak/.bashrc.bak.$ts.add_synergy_alias" && mv .bashrc.new .bashrc
  return $?
}

# end 10. env modifications

###############################################################################
#### 11. quoting and escaping
###############################################################################

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

function stripquotes() {
  string="${1:-}"
  if is_quoted "${string}"; then
    echo "${string:1:-1}"
    return 0
  fi
  echo "$string"
  return 0
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

# end 11. quoting and escaping

###############################################################################
#### 12. UI
###############################################################################

function user_feedback() {
  local subject
  local message
  local detritus
  local errors=()
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


# end 12. UI

###############################################################################
#### 13. Traps and exports
###############################################################################

set_log_ERROR() {
  if [[ "$(trap)" == *'RETURN'* ]]; then
    # if there's a return trap set, we can't have function calls in any other
    # trap or infinite recurse
    trap 'echo "$LINENO $BASH_COMMAND ${BASH_SOURCE[*]} ${BASH_LINENO[*]} ${FUNCNAME[*]}"' ERR
  else
    trap '{ [ -n "$FUNCNAME" ] && echo "${BASH_SOURCE[1]}:$(reallineno "$LINENO") returned $?"; } || echo "$BASH_COMMAND returned $?"' ERR
  fi
}

set_log_WARN() {
  trap
  set_log_ERROR
  alias fline='function_finder -L -f $BASH_SOURCE -F $FUNCNAME'
  trap 'printf "$INF"; [ -n "$FUNCNAME" ] && echo "$BASH_SOURCE:$(fline) $FUNCNAME $?"; [ -n "$BASH_COMMAND" ] && echo "$BASH_COMMAND: $?"; printf "$RST"' RETURN
}

set_log_DEBUG() {
  trap
  set_log_ERROR
  alias fline='function_finder -L -f $BASH_SOURCE -F $FUNCNAME'
  # preexec() {
  #   echo "executing $@"
  #   echo "history $(date '+%Y-%m-%d.%H:%M:%S')\t$(hostname)\t$(pwd)\t$1"
  # }
  # trap 'printf "TD$INF" && [ -n "$FUNCNAME" ] && echo "$BASH_SOURCE $FUNCNAME $?" && printf "$RST" || { printf "TD$INF"; [ -n "$BASH_COMMAND" ] && echo "$BASH_COMMAND: $?"; printf "$RST"; }' RETURN
  # #trap 'printf "$WRN"; [ -n "$FUNCNAME" ] && echo "$BASH_SOURCE:$(function_finder -L -f $BASH_SOURCE -F $FUNCNAME) $FUNCNAME $?"; [ -n "$BASH_COMMAND" ] && echo "$BASH_COMMAND: $?"; printf "$RST"' DEBUG
}

_utilsh_fs() {
  function_finder -f "$D/util.sh"
}

