#!/usr/bin/env bash

[ "$0" = "$BASH_SOURCE" ] && BASH_KIND_ENV=own || BASH_KIND_ENV=sourced;

# theres not really an easy way to use this in a substitution to solve the
# problem it's intended to solve, so it's mostly here as a reminder.
PRINTFDASH='\x2D'

set -E
set -o pipefail

SHOPTS=(
  direxpand
  cdable_vars
  cdspell
  cmdhist
  dirspell
  dotglob
  expand_aliases
  extglob
  failglob
  globstar
  gnu_errfmt
  histappend
  histreedit
  histverify
  lithist
  progcomp
  progcomp_alias
  shift_verbose
)

for opt in "${SHOPTS[@]}"; do
  shopt -s "$opt"
done

declare -F is_function > /dev/null 2>&1 || is_function() {
  ( declare -F "${1:-}" > /dev/null 2>&1 && return 0 ) || return 1
}
export -f is_function

alias reallineno='[ -n "$FUNCNAME" ] && lineno_in_func_in_file -f "${BASH_SOURCE[0]}" -F "$FUNCNAME" -l'
alias funcsourceline='[ -n "$BASH_SOURCE" ] && [ -n "$FUNCNAME" ] && { printf "[$FUNCNAME] $BASH_SOURCE" && [ -n "$LINENO" ] && echo ":$(reallineno $LINENO)"; }'

SBRC=true
case $- in
    *i*)
      source "$D/util.sh"
      #sosutil
      #set -x
      ;;
  *)
  # if the file is called instead of sourced, return will fail
  { [[ "$BASH_KIND_ENV" == sourced ]] && return 0; } || exit 0;
  ;;
esac


# see requires_modern_bash below
NO_BASH_VERSION_WARNING=false

EDITOR=vim
RSYNCOPTS="-rlutUPv"

function vimc() { # TODO: input validation
  if command=$(type -p "${1:-}"); then
    vim "$command"
  fi
}

# https://stackoverflow.com/questions/7665/how-to-resolve-symbolic-links-in-a-shell-script
function resolve_symlink() {
  test -L "$1" && ls -l "$1" | awk -v SYMLINK="$1" '{ SL=(SYMLINK)" -> "; i=index($0, SL); s=substr($0, i+length(SL)); print s }'
}

# TODO is this necessary?  maybe runonce?
function symlinks_setup() {
  self=$(resolve_symlink "$HOME/.bashrc")
  if [[ "$self" != "$D/.bashrc" ]]; then
    if [ -f "$D/.bashrc" ]; then
      ln -sf "$D/.bashrc" "$HOME/.bashrc"
    fi
  fi
  bp=$(resolve_symlink "$HOME/.bash_profile")
  if [[ "$bp" != "$D/.bash_profile" ]]; then
    if [ -f "$D/.bash_profile" ]; then
      ln -sf "$D/.bash_profile" "$HOME/.bash_profile"
    fi
  fi
  if ! [ -d "$HOME/.local/bin" ]; then
    mkdir -p "$HOME/.local/bin"
  fi
}
#symlinks_setup

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000000
HISTFILESIZE=2000000
# HISTTIMEFORMAT is set to $FSTSFMT in util.sh

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
fi

# some more ls aliases
if type exa >/dev/null 2>&1; then
  alias ll='exa -alF'
else
  alias ll='ls -alF'
fi
alias la='ls -A'
alias l='ls -CF'
alias tac='tail -r'

GREEN="$(tput setaf 46)"
YELLOW="$(tput setaf 220)"
BLUE="$(tput setaf 39)"
RED="$(tput setaf 1)"
PINK="$(tput setaf 165)"
RST="$(tput sgr0)"

# colored GCC warnings and errors
GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# for pre, post, and non-powerline setup
PS1="\[$PINK\][\@] \[$(tput setaf 46)\]\u\[$(tput setaf 220)\]@\[$(tput setaf 39)\]\h \[$(tput setaf 14)\]\w \[$(tput setaf 208)\]$\[$RST\] "

# keep PS1 in env for powerline_disable
pPS1="$PS1"

ps4_prompt() {
  local bminusc="bec:-c $BASH_EXECUTION_STRING "
  local bc="bc: $BASH_COMMAND "
  lineno='$LINENO '
  func='${FUNCNAME[0]} '
  bline='${BASH_LINENO[0]} '
  bsrcup='${BASH_SOURCE[0]} '
  bsrc='${BASH_SOURCE[0]}'
  ss='$BASH_SUBSHELL '
  sl='$SHLVL '
  cllr='$(caller)'
  PROGNAME=$(basename $0)
  pn='${PROGNAME}'
  cat < <({
  printf "%s%s: %s - caller: %s\n" "$bminusc" "$bc" "$lineno" "$cllr"
  printf "⎯sl:%sss:%s $(funcsourceline) >" "$sl" "$ss"  #"$bsrcup" "$bline" "$bsrc"
  })
}

function powerline_init() {
  if [[ $(uname) == "Darwin" ]] && [[ "$(launchctl getenv POWERLINE)" == "TRUE" ]] || [[ "$PL_SHELL" == "true" ]]; then
    function _update_ps1() {
      PS1=$(powerline-shell $?)
    }
    export -f _update_ps1
    _update_ps1

    if [[ $TERM != linux && ! $PROMPT_COMMAND =~ _update_ps1 ]]; then
      PROMPT_COMMAND="_update_ps1; $PROMPT_COMMAND"
    fi
  fi
}
powerline_init

function powerline_restart() {
  if [[ $(uname) == "Darwin" ]]; then
    launchctl setenv POWERLINE TRUE
  else
    export PL_SHELL="true"
  fi
  powerline_init
}

function powerline_disable() {
  if [[ $(uname) == "Darwin" ]]; then
    launchctl setenv POWERLINE "FALSE"
  else
    export PL_SHELL="false"
  fi
  if is_function "_update_ps1"; then
    unset -f _update_ps1
  fi
  export PROMPT_COMMAND="${PROMPT_COMMAND/'_update_ps1;'/''}"
  export USE_POWERLINE=false
  export PS1="$pPS1"
}

if [[ $(uname) != "Darwin" ]]; then
  PROMPT_COMMAND='last_exit=$?; history -a'
fi
function h() {
  history | grep "${1:-}"
}

# we'll want to disable powerline-status when running bash with
# set -x, as it creates a lot of noise
function setxdebug() {
  export DEBUG=true
  export LEVEL=DEBUG
  powerline_disable
  date=$(fsdate)
  xdebug_f="$LOGDIR/xdebug_$date"
  if ! [ -f "$xdebug_f" ]; then
    mkdir -p "$LOGDIR"
    touch "$xdebug_f"
  fi
  exec 99> "$xdebug_f"
  BASH_XTRACEFD=99
  export PS4="$(ps4_prompt)"
  set -x
}

function unsetxdebug() {
  set +x
  DEBUG= ; unset DEBUG
  powerline_init
}

function history_rm_range() {
  start=$1
  end=$2
  count=$(( end - start ))
  while [ $count -ge 0 ] ; do
      history -d $start
      ((count--))
  done
}

function history_rm_last() {
  if history_rm_range -2 -1; then
    return 0
  fi
  return 1
}

function setcompletion() {
  if [[ $(uname) == 'Darwin' ]]; then
    bc2=$(brew list bash-completion@2)
    if [ $? -gt 0 ]; then
      >&2 printf "Modern bash and brew installed completion (@2) recommended\n"
      >&2 printf "otherwise, ymmv\n\n"
      >&2 printf "brew install bash\n"
      >&2 printf "brew install bash-completion@2\n"
    fi
  fi
  # enable programmable completion features (you don't need to enable
  # this, if it's already enabled in /etc/bash.bashrc and /etc/profile
  # sources /etc/bash.bashrc).
  if ! shopt -oq posix; then
    if ! type -p _init_completion > /dev/null; then
      if [ -f /etc/profile.d/bash_completion.sh ]; then
        source /etc/profile.d/bash_completion.sh
      elif [[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]]; then
         source "/usr/local/etc/profile.d/bash_completion.sh"
      elif [ -f /usr/local/etc/bash_completion ]; then
        source /usr/local/etc/bash_completion
      elif [ -d /usr/local/etc/bash_completion.d ]; then
        for file in $(ls /usr/local/etc/bash_completion.d); do
          if [ -e "${file}" ]; then
            source "${file}"
          fi
        done
      elif [ -f /usr/share/bash-completion/bash_completion ]; then
        source /usr/share/bash-completion/bash_completion
      elif [ -f /etc/bash_completion ]; then
        source /etc/bash_completion
      fi
    fi
  fi
  # double check and print an error if we didn't succeed
  if ! type -p _init_completion; then
    >&2 printf "_init_completion not available, we may have failed to setup\n"
    >&2 printf "bash completion."
  fi
}

# aliases generally here instead of .bash_aliases
# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

alias vbrc="vim $HOME/.bashrc && source $HOME/.bashrc"
alias brc="vimcat ~/.bashrc"
alias sbrc="source $HOME/.bashrc"
alias sutil="source $D/util.sh"
alias vutil="vim $D/util.sh && sutil"
alias sex="source $D/existence.sh" # heh
alias vex="vim $D/existence && sex"
alias mrsync="rsync $RSYNCOPTS"

# And a few globals
## convenient regex to use with -v when grepping across many files
IMGx="\\.(jpe?g|png|jpg|gif|bmp|svg|PNG|JPE?G|GIF|BMP|JPEG|SVG)$"
export GH="$HOME/src/github"

if [ -f "$HOME/.localrc" ]; then
  source "$HOME/.localrc"
fi

_bashrc_fs() {
  function_finder "$HOME/.bashrc"
}
