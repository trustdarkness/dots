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

shopt -s expand_aliases
source "$D/loader.sh"
path_append "$D"

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
      >&2 printf "${1:-}" "${@:2}"
    else
      >&2 printf "$@"
    fi
    if ! [[ "$*" == *'\n'* ]]; then
      >&2 printf '\n'
    fi
  }
fi

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

# preferred format strings for date for storing on the filesystem
FSDATEFMT="%Y%m%d" # our preferred date fmt for files/folders
printf -v FSTSFMT '%s_%%H%%M%%S' "$FSDATEFMT" # our preferred ts fmt for files/folders
LAST_DATEFMT="%a %b %e %k:%M" # used by the "last" command
PSTSFMT="%a %b %e %T %Y" # date given by (among others) ps -p$pid -o'lstart' ex: Thu Dec 26 21:17:01 2024
USCLOCKTIMEFMT="%k:%M %p"
HISTTIMEFORMAT="$FSTS"

function fsdate() {
  date +"${FSDATEFMT}"
}

function fsts_to_fsdate() {
  date -d -f "$FSTSFMT" "${1:-}" "$FSDATEFMT"
}

function fsts() {
  date +"${FSTSFMT}"
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
    date -d -f "$FSTSFMT" "${1:-}" +"%s"
  fi
  return $?
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

# Templates for colored stderr messages
printf -v E "%s[%s]" $ERR "ERROR"
printf -v W "%s[%s]" $WRN "WARN"
printf -v I "%s[%s]" $INF "INFO"
printf -v B "%s[%s]" $DBG "DEBUG"

# implementing log levels selectively for simplicity and to avoid
# namespace collisions, i.e. with the info command
alias err='_log "$E" "$LINENO"'
alias warn='_log "$W" "$LINENO"'
alias debug='_log "$B" "$LINENO"'

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

# Log to both stderr and a file (see above).  Should be called using
# wrapper functions below, not directly
_log() {
  local lineno
  local funcname
  local ts=$(fsts)
  local pid="$$"
  srcp="${BASH_SOURCE[1]}"
  src=$(basename "$srcp")
  local level="$1"
  shift
  if [ -z "$LEVEL" ]; then
    local LEVEL=WARN
  fi
  # we opportunistically get the lineno if we can
  if is_int "$1"; then
    err_in_func="$1"
    shift
  fi
  local message="$@"
  if [ -z "$LOGFILE" ]; then
    if [[ "$srcp" == "environment" ]]; then
      LOGFILE="$LOGDIR/util.sh.log"
    else
      LOGFILE="$LOGDIR/$src.log"
    fi
  fi
  # if called by struct error the FUNCNAME indices are off by 1
  # if [[ "${FUNCNAME[*]}" == *"_struct_err"* ]]; then
  #   findex=2
  # else
  #   findex=1
  # fi
  # if [ "${#FUNCNAME[@]}" -gt $findex ]; then
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
  printf -v line_leader "$LOGFMT" "$ts" "$funcname" "$level" "pid: ${pid}" "$src"
  (

    if _to_echo "$this_level" "$LEVEL"; then
      #exec 3>&1
      # remove coloring when going to logfile
      echo "$line_leader $message${RST}" 2>&1 | sed 's/\x1B\[[0-9;]*[JKmsu]//g' | tee -a "$LOGFILE"
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

# print a structured err, when the command with arguments,
# other relevant vars, exit status, and output, says all that needs
# to be said
# Args: return code, command, args, output, stderr
# _struct_err() {
#   ret=$1
#   cmd=$2
#   args=$3
#   out=$4
#   err=$5
#   retm=$(_prs "$ret")
#   varsm=$(_prvars)
#   com=$(_prcao "$cmd" "$args" "$out" "$err")
#   printf -v err_msg "%s %s %s" "$retm" "$varsm" "$com"
#   err "$err_msg"
# }

# runs a command, wrapping err handling
# args: command to run, args
# on success, returns 0 and echos the child back to the parent
# on failure, calls _struct_err, which outputs error to stderr
# and to \$LOGFILE
# _lc() {
#   cmd="$1"; shift
#   #info "_lc: $cmd $@"
#   {
#       IFS=$'\n' read -r -d '' err;
#       IFS=$'\n' read -r -d '' out;
#       IFS=$'\n' read -r -d '' ret;
#   } < <((printf '\0%s\0%d\0' "$($cmd $@)" "${?}" 1>&2) 2>&1)
#   if [ $ret -gt 0 ]; then
#     _struct_err "$ret" "$cmd" "$@" "$out" "$err"
#     return $ret
#   else
#     echo "$out" && return 0
#   fi
# }
##################### end logging code #########################################

# TODO do these belong in .bashrc or .bash_aliases?
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

# TODO use is_function?
if ! declare -F "exists" > /dev/null 2>&1; then
  source "$D/existence.sh"
fi



# for my interactive shells, the full environment setup is constructed
# from bashrc, but for scripts that rely on it, this function should be
# called to make sure all is as expected.
# TODO: create teardown that remove all namerefs added by setup
function util_env_load() {
  # this represents all the possible sources at the moment, but only
  # including as options as needed, otherwise it would be taking an
  # already silly thing and making it ridiculous.
  local exu=true # -e
  local up=false # -u
  local fsau=false # -f
  local osu=true # -o
  local jl=false # -j
  local xl=false # -x
  local ku=false # -k
  local lb=false # -l
  local bsu=false
  local iu=false # -i
  local mb=false
  local md=false # -d
  local bc=false
  local bs=false # -b
  while [ $# -gt 0 ]; do
    case "${1:-}" in
      "-e"|"--existence")
        exu=true
        shift
        ;;
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
      "-o"|"--osutil")
        osu=true
        shift
        # TODO: finish implementing
        ;;
      "-j"|"--json-like")
        osu=true
        shift
        # TODO: finish implementing
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

dgrep() {
  grepargs=()
  while [[ "${1:-}" == "-"* ]]; do
    grepargs+=( "${1:-}" )
    shift
  done
  sterm="${1:-}"
  if [ -z "$D" ]; then
    if confirm_yes "D not in env, do you want to search PATH?"; then
      #TODO
      :
    fi
  fi
  total_found=0
  for item in "$D"/*; do
    # if there are ever more exceptions, make this more visible
    { [ -f "$item" ] && [[ "$item" != *LICENSE ]] && file=$item; } || continue
    found=$(grep -n ${grepargs[@]} "$sterm" "$file"); ret=$?||true
    if [ $ret -eq 0 ]; then
      echo "$file"
      while read -r line ; do
        echo "  ${line/$sterm/${GREEN}${sterm}${RST}}"
      done < <(echo "$found")
      echo
      ((total_found+=$(echo "$found"|wc -l|xargs)))
    fi
  done
  if [ $total_found -gt 0 ]; then
    return 0
  fi
  return 1
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

# https://www.reddit.com/r/sysadmin/comments/t5xnco/curl_wtfismyipcomtext_fast_way_to_find_a/
ip-get-external() {
  curl wtfismyip.com/text
  return $?
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
  local pid="${1:-}"
  # favoring readability over performance
  local name="$(ps -p$pid -ocommand=)"
  if string_contains "/" "$name"; then name=$(basename "$name"); fi
  local cpu="$(ps -p$pid -o'%cpu=')"
  local mem="$(ps -p$pid -o'%mem=')"
  local started="$(ps -p$pid -olstart=)"
  localized=$(_localize_ps_time "$started")
  IFS='' read -r -d '' pidinfo <<"EOF"
 Process: %s
   PID: %s
   Current CPU: %s %%
   Current RAM: %s %%
   Started at: %s
EOF
  # for field in "$localized"; do pidinfo+=" %s"; done
  printf "$pidinfo" "$pid" "$name" "$cpu" "$mem" "$localized"
}

function add_permanent_bash_alias_to_bashrc() {
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
printf -v VALID_POSIXPATHS_REGEX '[\/*%s]+' "$VALID_POSIXPATH_EL_CHARS";
BASH_FUNCTION_WITH_NAME_PCREREGEX='(function %s *\(\) +{|%s *\(\) +{|%s +{)'

function_regex() {
  printf -v "${1:-}" "$BASH_FUNCTION_WITH_NAME_PCREREGEX" "${2:-}" "${2:-}" "${2:-}"
}
function_regex BASH_FUNCTION_PCREREGEX "[A-z0-9_]+"
_BWVR='^bash[_-]{0,1}(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|'
_BWVR+='[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*'
_BWVR+='[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$'
BASH_WITH_VERSION_REGEX="$_BWVR"

bash_shebang_validator() {
  _env_ok() {
    to_test="${1:-}"
    { pcregrep "\#\!$VALID_POSIXPATHS_REGEX" > /dev/null 2>&1 < <(echo "$to_test"); ret=$?; } ||
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
  if string_contains "/" "$name"; then
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

function_finder() {
  l=$((LINENO-1))
  usage() {
    cat <<-'EOF'
function_finder - prints functions declared in a bash script

Args:
  -f filename of bash script to search in
  -F (optional) function name to search for, can be specified
     more than once to find multiple functions
  -l print line numbers of function declarations
  -L only print the line numbers
  -n include nested functions (false if not speicified)
  -w wide display mode, prints functions in columns instead
     of one per line
  -h print this text
EOF
  }
  unset ffs
  ffs=()
  oargs=( "$@" )
  local pcre2grepopts=('-n' '--null')
  local flinenos=false
  local onlylinenos=false
  declare -ga functions
  functions=()
  local nested=false
  local pager="cat"
  unset files
  declare -ga files
  files=()
  optspec="nlLf:F:wh"
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
        file="${OPTARG}"
        ;;
      F)
        functions+=("${OPTARG}")
        ;;
      w)
        pager="column"
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
  local _argc_post=$1
  array_to_set "functions"

  _pfunctions_to_array() {
    while IFS= read -r line; do
      funcdef=$(echo "$line" | sed "s/\($func_name\)\([(].*\)/\1/g")
      [ -n "$funcdef" ] && funcs_in_file+=( "$funcdef" )
    done < <(pcre2grep ${pcre2grepopts[@]} "$func_regex" "$file"); ret=$?;
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
    return 1
  }
  array_to_set "functions"
  i=0
  unset funcs_in_file
  funcs_in_file=()
  if [ -f "${file}" ]; then
    if [ "${#functions[@]}" -gt 0 ]; then
      for func_name in "${functions[@]}"; do
        function_regex func_regex "$func_name"
        _pfunctions_to_array
      done
    else
      func_regex="$BASH_FUNCTION_PCREREGEX"
      _pfunctions_to_array
    fi
    for linefunction in "${funcs_in_file[@]}"; do
      lineno=$(echo "$linefunction" | cut -d":" -f1)
      fline=$(echo "$linefunction" | cut -d":" -f2)
      { fname=$(_process_line "$fline") &&
        { if $flinenos; then
            printf "%d " "$lineno"
          fi
          if ! $onlylinenos; then
            printf "%s\n" "$fname"
          fi
          ((i++)) }
      } || continue
    done | $pager
  fi
  echo
}

loader-add() {
  # deprecate
  util_env_load -u
  printf -v fargs '"$@"'
  printf -v fret '"$?"'
  bashlib="${1:-}"
  if ! is_absolute "$bashlib"; then
    abspath=$(realpath "$bashlib")
    if [[ "$abspath" == "$(realpath "$D/$bashlib")" ]]; then
      bashlib="$D/$bashlib"
    else
      bashlib="$abspath"
    fi
  fi
  loaderlib="$D/loader.sh"
  if ! is_bash_script "$bashlib"; then
    err "Usage: loader_add -some -flags <some_bashlib.sh>"
    return 1
  fi
  preamble_text="$bashlib function loaders begin here"
  epilogue_text="$bashlib function loaders end here"
  if plline=$(grep -n "$preamble_text" "$loaderlib"); then
    llline=$(grep -n "$epilogue_text" "$loaderlib")
    range=""
    if is_int "$plline" && is_int "$llline"; then
      for line in "${plline}" "${llline}"; do
        range+=$(echo "$line" | cut -d":" -f"1")
        if [[ "$range" == *','* ]]; then
          range+='d';
        else
          ((range--))
          range+=','
        fi
      done
      echo "$range"
      cy="$bashlib is already present in loader.sh "
      cy+="replace current contents?"
      if confirm_yes "$cy"; then
        sed -i.bak "$range" "$loaderlib"
      else
        return 2
      fi
    else
      err "error in format of existing $loaderlib, please investigate"
      return 3
    fi
  fi
  echo " " >> $loaderlib
  echo "######## $preamble_text ########" >> $loaderlib
  functions_in_bashlib=($(function_finder -f "$bashlib"))
  failures=0
  for fname in "${functions_in_bashlib[@]}"; do
############
    cat <<-EOF >> $loaderlib || ((failures++))
declare -F "$fname" > /dev/null 2>&1 || $fname() {
  unset -f ${functions_in_bashlib[@]}; source "$bashlib"; $fname $fargs
  return $fret
}

EOF
############
  done
    cat <<-EOF >> $loaderlib || ((failures++))
_unset_$(_vslugify $(basename $bashlib))_fs() {
  unset -f ${functions_in_bashlib[@]};
  return $fret
}

EOF
  echo "######## $epilogue_text ##########" >> $loaderlib
  if [ $failures -eq 0 ]; then
    se "$((${#functions_in_bashlib[@]}+1)) function declarations added to $loaderlib"
  else
    se "$(( $((${#functions_in_bashlib[@]}+1)) - failures)) added.  $failures failed."
  fi
  return $failures
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
        [ -f "$filepath" ] || { error "no file at $filepath"; return 2; }
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
    error "couldn't find definition for $function_name at the top level of $bn"
    return 3
  fi

}

BASH_VARNAME_REGEX='[A-z0-9_]+'
BASH_LOCAL_PREFIX='^\h*local\h+([[-][A-z]]*|\h*)\h*'
printf -v BASH_LOCAL_VAR_PCREREGEX '%s%s.*' "$BASH_LOCAL_PREFIX" "$BASH_VARNAME_REGEX"
printf -v BASH_LOCAL_VAR_SED_EXTRACT_NAME2_REGEX '[ \t]*local[ \t]+([[-][A-z] ]*|[ \t]*)\(%s\).*' "$BASH_VARNAME_REGEX"

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
  declare -ga _names

  # case: global function names
  _names=$(function_finder "$script")

  # get variables declared as local for exclusion (this may result in false positives)
  declare -ga localvars
  declare -a localvarlines
  printf -v sedstr 's/%s/One: \\1/g' "$BASH_LOCAL_VAR_SED_EXTRACT_NAME2_REGEX"
  while IFS= read -r matchedline; do
    # printf "($matchedline) "
    lname=$(echo "$matchedline"| sed 's/.*local//g'| # remove local
                                        sed 's/-[A-z]//g') # remove any flags
    if [[ "$lname" == *'='* ]]; then
      lname=$(echo "$lname" | cut -d'=' -f1)
    fi
    localvars+=( "$lname" )
  done < <(pcre2grep --null "$BASH_LOCAL_VAR_PCREREGEX" "$script")
  # localvarlines=( $(grep '^[[:space:]]*local[[:space:]]*[[-][[:alpha:]]]*[[:space:]]*[[[:alnum:]][_]]*' "$script") )
  # for line in "${localvarlines[@]}"; do
  #   wequal=$(echo "$line"|grep "=")
  #   if [ $? -eq 0 ]; then
  #     # we're expecting something like "local foo=bar" and we want foo
  #     localvars+=( $(echo "$wequal" | awk '{print$1}' |awk -F'=' '{print$1}') )
  #   else
  #     localvars+=( $(echo "$line" | awk '{print$2}') )
  #   fi
  # done

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
  existing_namerefs="$(grep -E '^NAMEREFS_[A-z]+\=\(.*\)$' "${script}")"
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
  local -n script_namerefs="$expected_name"

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
  sed -ri.bak 's/^NAMEREFS_[A-z]+\=\(.*\)$//g' "$script"
  # add it in a nice-to-look-at format:
  printf "\n\n${expected_name}=(" >> "$script"
  for quoted_nameref in "${out_namerefs[@]}"; do
    printf "$quoted_nameref" >> "$script"
  done
  printf ")\n" >> "$script"
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
function dse() {
  if $DEBUG; then
    if [ $# -eq 2 ]; then
      >&2 printf "${1:-}\n" "${@:2:-}"
    else
      >&2 printf "${1:-}\n"
    fi
  fi
}

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

in-path() {
  to_find="${1:-}"
  found=()
  while IFS= read -r -d $'\0' file; do
    found+=( "$file" )
  done < <(find $(echo "$PATH" | tr ":" " ") -type f -name "$to_find" -print0 2>/dev/null)
  if [ ${#found[@]} -eq 0 ]; then
    return 1
  fi
  for item in "${found[@]}"; do echo "$item"; done
  return 0
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

function sata_bus_scan() {
  sudo sh -c 'for i in $(seq 0 4); do echo "0 0 0" > /sys/class/scsi_host/host$i/scan; done'
}

function get_cache_for_OS () {
  case $(what_os) in
    'GNU/Linux')
      CACHE="$HOME/.local/cache"
      mkdir -p "$CACHE"
      OSUTIL="$D/linuxutil.sh"
      function sosutil() {
        source "$D/linuxutil.sh"
      }
      alias vosutil="vim $D/linuxutil.sh && sosutil"
      ;;
    "MacOS")
      CACHE="$HOME/Library/Application Support/Caches"
      OSUTIL="$D/macutil.sh"
      function sosutil() {
        source $D/macutil.sh
      }
      alias vosutil="vim $D/macutil.sh && vosutil"
      ;;
  esac
  export CACHE
}
get_cache_for_OS

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

# TODO: deprecate
function install_util_load() {
  if undefined "sau"; then
    source "$D/installutil.sh"
  fi
  i
  return $?
}

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
  declare -ga sourcerers
  declare -ga sourcerees
function source() {
  if [[ "$LEVEL" == DEBUG ]]; then debug "$(caller) fcall: source $@"; fi
  sourcerers+=( "${BASH_SOURCE[0]}" )
  sourcerees+=( "${3:-}" )
  if [ $# -gt 2 ]; then
    if [ -f "${3:-}" ]; then
      src="${BASH_SOURCE[0]}"
      #echo "sff $src $2"
      if [ -n "${2:-}" ]; then
        lineno=$(reallineno "${1:-}") || lineno="${1:-}"
      fi
      echo "$src:$lineno sourced ${3:-}"
      builtin source "${3:-}"
      return $?
    fi
  else
    warn "debuggable source incorrectly called"
    builtin source "$@"
    return $?
  fi
}
  export -f source
  alias source='\source $LINENO $FUNCNAME'
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

