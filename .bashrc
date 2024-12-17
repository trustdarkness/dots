#e!/usr/bin/env bash
if ! declare -F is_function > /dev/null 2>&1; then
  is_function() {
    ( declare -F "${1:-}" > /dev/null 2>&1 && return 0 ) || return 1
  }
fi

shopt -s direxpand
shopt -s cdable_vars

if [ -z "${D}" ]; then
  if [ -d "$HOME/src/github/dots" ]; then
  export D="$HOME/src/github/dots"
   else
    detect_d
  fi
fi

case $- in
    *i*)
      SBRC=true
      #set -x
      ;;
  *)
  return
  ;;
esac

function detect_d() {
  # -z || here for first run conditions
  if [ -z $DEBUG ] || $DEBUG; then
    >&2 printf ".bashrc sourced from ${BASH_SOURCE[@]}\n"
  fi
  if [[ "${BASH_SOURCE[0]}" == ".bashrc" ]]; then 
    if [ -f "$(pwd)/util.sh" ]; then 
      D=$(pwd)
      export D
      return 0
    fi
  else
    : # REALBASHRC=$(readlink ${BASH_SOURCE[0]})
    # D=$(dirname $REALBASHRC)
  fi
  if [ -z "$D" ]; then 
    >&2 printf "no luck finding D, please set"
    return 1
  fi
}

# avoid prepending path if our changes are already there,
# but be sure that brew installed bash in /usr/local/bin
# is caught before the system bash in /bin
if [[ "${PATH}" != "*.local/sourced*" ]]; then
  PATHRC="$PATH"
  PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:$HOME/Applications:/usr/sbin:/opt/bin:$PATH:$HOME/.local/sourced"
  export PATH
fi

# see requires_modern_bash below
NO_BASH_VERSION_WARNING=false

export EDITOR=vim
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
  if [[ $(uname) == "Darwin" ]] && ! [ -L "$HOME/.local/bin/bellicose" ]; then 
    ln -sf "$D/bellicose.sh" "$HOME/.local/bin/bellicose"
  fi
  if ! [ -L "$HOME/.local/sourced" ]; then
    ln -sf $HOME/.local/bin $HOME/.local/sourced
  fi
  if ! [ -L "$HOME/.globals" ]; then
    ln -sf "$D/.globals" "$HOME/"
  fi
}
symlinks_setup

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000000
HISTFILESIZE=2000000

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

function fnegrep() {
  sterm="${1:-}"
  filename="${2:-}"
  if [ -n "$sterm" ] && [ -f "$filename" ]; then 
    out=$(grep -E -n "$sterm" "$filename" 2> /dev/null)
    if [ $? -eq 0 ]; then 
      split -a -F'\n' "$out"
      grep_lines=( "${split_array[@]}" )
      failures=0 # seems unnecessary, but just in case
      for line in "${grep_lines[@]}"; do 
        printf "%20s %s\n" "$filename" "$line"
        if [ $? -gt 0 ]; then 
          ((failures++))
        fi
      done 
      return $failures
    else  # if grep $? -eq 0
      return $?
    fi # endif grep ?$
  fi # endif -n sterm -f filename
  return 1
}

function dgrep() {
  find "$D" -maxdepth 1 -exec bash -c "fnegrep ${1:-} {}" \;
  if gt $? 0; then 
    return 1
  fi
  return 0
}

# https://unix.stackexchange.com/questions/148/colorizing-your-terminal-and-shell-environment
function _colorman() {
  env \
    LESS_TERMCAP_mb=$'\e[1;35m' \
    LESS_TERMCAP_md=$'\e[1;34m' \
    LESS_TERMCAP_me=$'\e[0m' \
    LESS_TERMCAP_se=$'\e[0m' \
    LESS_TERMCAP_so=$'\e[7;40m' \
    LESS_TERMCAP_ue=$'\e[0m' \
    LESS_TERMCAP_us=$'\e[1;33m' \
    LESS_TERMCAP_mr=$(tput rev) \
    LESS_TERMCAP_mh=$(tput dim) \
    LESS_TERMCAP_ZN=$(tput ssubm) \
    LESS_TERMCAP_ZV=$(tput rsubm) \
    LESS_TERMCAP_ZO=$(tput ssupm) \
    LESS_TERMCAP_ZW=$(tput rsupm) \
    GROFF_NO_SGR=1 \
      "$@"
}
alias man="LANG=C _colorman man"
function perldoc() { command perldoc -n less "$@" |man -l -; }

if type grc grcat >/dev/null 2>&1; then
  function colourify() {  # using this as a function allows easier calling down lower
    if [[ -t 1 || -n "$CLICOLOR_FORCE" ]]
      then ${GRC:-grc} -es --colour=auto "$@"
      else "$@"
    fi
  }

  # loop through known commands plus all those with named conf files
  for cmd in g++ head ld ping6 tail traceroute6 `locate grc/conf.`; do
    cmd="${cmd##*grc/conf.}"  # we want just the command
    type "$cmd" >/dev/null 2>&1 && alias "$cmd"="colourify $cmd"
  done

  # This needs run-time detection. We even fake the 'command not found' error.
  function configure() {
    if [[ -x ./configure ]]; then
      colourify ./configure "$@"
    else
      echo "configure: command not found" >&2
      return 127
    fi
  }

  unalias ll 2>/dev/null
  function ll() {
    if [[ -n "$CLICOLOR_FORCE" || -t 1 ]]; then  # re-implement --color=auto
      ls -l --color=always "$@" |grcat conf.ls
      return ${PIPESTATUS[0]} ${pipestatus[1]} # exit code of ls via bash or zsh
    fi
    ls -l "$@"
  }
fi


# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# for pre, post, and non-powerline setup
export PS1="\[$(tput setaf 46)\]\u\[$(tput setaf 220)\]@\[$(tput setaf 39)\]\h \[$(tput setaf 14)\]\w \[$(tput sgr0)\]$ "
pPS1="$PS1"

# some more ls aliases
if type exa >/dev/null 2>&1; then
  alias ll='exa -alF'
else
  alias ll='ls -alF'
fi
alias la='ls -A'
alias l='ls -CF'
alias tac='tail -r'

# theres not really an easy way to use this in a substitution to solve the
# problem it's intended to solve, so it's mostly here as a reminder.
PRINTFDASH='\x2D'

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

function h() {
  history | grep "${1:-}"
}

# we'll want to disable powerline-status when running bash with
# set -x, as it creates a lot of noise
function setxdebug() {
  export DEBUG=true
  powerline_disable
  export PS1='$? > '
  export PS4='$LINENO: '
  _update_ps1
  if ! type -p _init_completion; then
    setcompletion
  fi
  trap -- '_lp_reset_runtime;preexec_invoke_exec' DEBUG
  set -x
}

function unsetxdebug() {
  set +x
  unset DEBUG
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

if [ -z "${DEBUG}" ] || ! $DEBUG; then
 if declare -f powerline_init > /dev/null; then
   powerline_init
 fi
fi

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

## convenient regex to use with -v when grepping across many files
export IMGx="\\.(jpe?g|png|jpg|gif|bmp|svg|PNG|JPE?G|GIF|BMP|JPEG|SVG)$"

GRC_ALIASES=true
[[ -s "/etc/profile.d/grc.sh" ]] && source /etc/grc.sh

if [ -f "$HOME/.localrc" ]; then 
  source "$HOME/.localrc"
fi

if ! is_function "util_env_load"; then
  source $D/util.sh
fi
