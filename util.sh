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
alias vsc="vim $HOME/.ssh/config"
alias pau="ps auwx"
alias paug="ps auwx|grep "
alias paugi="ps awux|grep -i "
alias rst="sudo shutdown -r now"
alias gh="mkdir -p $HOME/src/github && cd $HOME/src/github"
alias gl="mkdir -p $HOME/src/gitlab && cd $HOME/src/gitlab"
alias gc="git clone"
export GH="$HOME/src/github"

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
  local bc=false
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
  if untru $osutil_in_env && $osu; then
    osutil_load
  fi
}




# preferred format strings for date for storing on the filesystem
FSDATEFMT="%Y%m%d" # our preferred date fmt for files/folders
FSTSFMT="${FSDATEFMT}_%H%M%S" # our preferred ts fmt for files/folders
LAST_DATEFMT="%a %b %e %k:%M" # used by the "last" command

function fsdate() {
  date +"${FSDATEFMT}"
}

function fsts() {
  date +"${FSTSFMT}"
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
function debug() {
  if $DEBUG; then
    if [ $# -eq 2 ]; then 
      >&2 printf "${1:-}\n" "${@:2:-}"
    else
      >&2 printf "${1:-}\n"
    fi
  fi
}

function term_bootstrap() {
  termschemes_bootstrap
  termfonts_bootstrap
}

# my basic edits to import-schemes.sh below will detect and add color
# schemes for xfce4-terminal and konsole.  At the bare minimum, I plan
# to add terminator in addition to iTerm which is what the script
# was originally written for, so this function remains generally OS 
# agnostic.
function termschemes_bootstrap() {
  if ! [ -d "$GH/Terminal-Color-Schemes" ]; then 
    ghc "git@github.com:trustdarkness/Terminal-Color-Schemes.git"
  fi
  cd "$GH/Terminal-Color-Schemes"
  tools/import-schemes.sh
  cd -
}

# in the spirit of consistency, we'll keep these together
function termfonts_bootstrap() { 
  if ! $(fc-list |grep Hack-Regular); then 
    if ! $(i); then  
      se "no installutils.sh" 
      return 1 
    fi 
    if ! $(sai fonts-hack); then  
      se "could not install fontshack with ${sai}"
      return 1
    fi
  fi
  return 0
}
alias debug="se"

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
  if [ -f "${to_add}" ]; then 
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

# I'm not trying to be lazy, I'm trying to make the code readable
function split() {
  to_split="${1:?'Provide a string to split and (optionally) a delimiter'}"
  delimiter="${2:-' '}"
  awk -F"${delimiter}" '{print $0}'
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

 # super sudo, enables sudo like behavior with bash functions
function ssudo () {
  [[ "$(type -t $1)" == "function" ]] &&
    ARGS="$@" && sudo bash -c "$(declare -f $1); $ARGS"
}
alias ssudo="ssudo "

# stolen from https://stackoverflow.com/questions/8654051/how-can-i-compare-two-floating-point-numbers-in-bash
function is_first_floating_number_bigger () {
    number1="$1"
    number2="$2"

    [ ${number1%.*} -eq ${number2%.*} ] && [ ${number1#*.} \> ${number2#*.} ] || [ ${number1%.*} -gt ${number2%.*} ];
    result=$?
    if [ "$result" -eq 0 ]; then result=1; else result=0; fi

    __FUNCTION_RETURN="${result}"
}


# To help common bash gotchas with [ -eq ], etc, this function simply
# takes something we hope to be an int (arg1) and returns 0 if it is
# 1 otherwise
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

function boolean_or {
  for b in "$@"; do
    se "testing ${b}"
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

function osutil_load() {
  if [ -z "$osutil_in_env" ] || $osutil_in_env; then
    if [[ "$(uname)" == "Linux" ]]; then
      source $D/linuxutil.sh
      alias sosutil="source $D/linuxutil.sh"
      alias vosutil="vim $D/linuxutil.sh && sosutil"
    elif [[ "$(uname)" == "Darwin" ]]; then
      source $D/macutil.sh
      alias sosutil="source $D/macutil.sh"
      alias vosutil="vim $D/macutil.sh && vosutil"
    fi
  fi
}
osutil_load

alias sall="sbrc; sglobals; sutil; sosutil"

# initialized the helper library for the package installer
# for whatever the detected os environment is
function i() {
  source $D/installutil.sh
}

# for the most common ones, since i got used to having them
alias sai="i; sai"
alias sas="i; sas"
alias sauu="i; sauu"

# for other files to avoid re-sourcing
utilsh_in_env=true
