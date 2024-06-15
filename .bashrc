#!/usr/bin/env bash

if [ -z "${D}" ]; then
  export D="$HOME/src/github/dots"
fi

case $- in
    *i*)
      SBRC=true
      source $D/util.sh
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
    D=$(pwd)
  else
REALBASHRC=$(readlink ${BASH_SOURCE[0]})
D=$(dirname $REALBASHRC)
  fi
  if [ -n "$D" ]; then 
    >&2 printf "no luck finding D, please set"
    return 1
  fi
}

source "$D/existence.sh"

# see requires_modern_bash below
NO_BASH_VERSION_WARNING=false

# avoid prepending path if our changes are already there,
# but be sure that brew installed bash in /usr/local/bin
# is caught before the system bash in /bin
if [[ "${PATH}" != "*.local/sourced*" ]]; then
  export PATH="$HOME/bin:$HOME/.local/bin:$HOME/Applications:/usr/local/bin:/bin:/usr/bin:/usr/sbin:$PATH:$HOME/.local/sourced"
fi
# Detects the bash version and if < 4.2, prints a warning for the user
# this warning can be supressed by setting the environment variable
# NO_BASH_VERSION_WARNING=true
function requires_modern_bash() {
  # Some things in this bashrc are only valid for bash 4.2ish and up
  if [[ bash_version < 4.3 ]]; then # 4.3 because pass by reference
                                      # https://stackoverflow.com/questions/540298/passing-arguments-by-reference
    if [ -n "${NO_BASH_VERSION_WARNING}" ] && ! "${NO_BASH_VERSION_WARNING}"; then
      echo "Many of the utility functions associated with the code you're running"
      echo "depend on features in modern(ish) bash (>= 4.2). Use at your own risk"
      echo "(suppress by setting NO_BASH_VERSION_WARNING=true)"
      if [[ $(uname -a) == "Darwin" ]]; then
        echo " "
        echo "On MacOS, installing modern bash is quite simple with homebrew"
        if [ -f "$D/macbootstraps.sh" ]; then
          source "$D/macbootstraps.sh"
          choices_legacy "$MACBASHUPS" "$MACBASHUPA"
          cleanup_macbootstraps
          if [[ bash_version < 4.3 ]]; then
            echo " "
            echo "execution will continue but somethings will not work or may break"
            echo "or function improperly."
            >/dev/tty printf '%s' "Continue? (Y/n)"
            [[ $BASH_VERSION ]] && </dev/tty read -rn1
            if ! [[ "${REPLY,,}" == "y"* ]]; then
              return 1
            fi
          fi # end chosen 0
        fi
      fi
    fi
  fi
}
# The goal is to use this almost like a decorator in python so as to
# demarcate things that won't work by default on MacOS (or other ancient bash)
alias rmb="requires_modern_bash"

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
  if [[ uname == "Darwin" ]] && ! [ -L "$HOME/.local/bin/bellicose" ]; then 
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
HISTSIZE=10000
HISTFILESIZE=20000

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
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# for pre, post, and non-powerline setup
export PS1="\[$(tput setaf 46)\]\u\[$(tput setaf 220)\]@\[$(tput setaf 39)\]\h \[$(tput setaf 14)\]\w \[$(tput sgr0)\]$ "

# some more ls aliases
if type exa >/dev/null 2>&1; then
  alias ll='exa -alF'
else
  alias ll='ls -alF'
fi
alias la='ls -A'
alias l='ls -CF'

# theres not really an easy way to use this in a substitution to solve the
# problem it's intended to solve, so it's mostly here as a reminder.
PRINTFDASH='\x2D'

# breadcrumbs... for (relatively?) tearfree cross platform setup:
function powerline_bootstrap() {
  if ! type pipx >/dev/null 2>&1; then
    if ! [ -n "${p3}" ]; then
      if ! p3=$(type -p python3); then
        echo "python3 doesn't seem to be in \$PATH..."
        # TODO: finish
      fi
    fi
    pipx install powerline-status
    mkdir -p .local/share/powerline
		if [ -z "${psh}" ]; then
      if ! psh=$(find $(pipx list |head -n1 |awk '{print$NF}') -name "powerline.sh" 2> /dev/null |grep "bash"); then
			  se "can't find powerline.sh, assign psh= and run again"
        return 1
			fi
		fi

    ln -is "${psh}"	$HOME/.local/share/powerline/
  else
    >&2 printf "Would be less painful with pipx."
    >&2 printf "  on debian based systems, try sudo apt install pipx"
    >&2 printf "  on mac, install homebrew, then brew cask python; brew cask pipx"
    >&2 printf "Or something, you know the deal."
  fi
}

# Powerline
function powerline_init() {
  powerline-daemon -q
  declare -x POWERLINE_BASH_CONTINUATION=1
  declare -x POWERLINE_BASH_SELECT=1
  declare -x POWERLINE_PROMPT="user_info last_status scm python_venv ruby cwd"
  declare -x POWERLINE_PADDING=1
  declare -x POWERLINE_COMPACT=0
  declare -x PS1="$(powerline shell left)"
  source $HOME/.local/share/powerline/powerline.sh
}

function _update_ps1() {
   export orig_ps1="$(~/powerline-shell.py $? 2> /dev/null)"
}
export PROMPT_COMMAND="_update_ps1"

function powerline_disable() {
  export USE_POWERLINE=false
  unset POWERLINE_BASH_CONTINUATION
  unset POWERLINE_BASH_SELECT
  unset POWERLINE_PROMPT
  unset POWERLINE_PADDING
  unset POWERLINE_COMPACT
  powerline-daemon --kill
  unset PROMPT
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

# convenient regex to use with -v when grepping across many files
export IMGx="\\.(jpe?g|png|jpg|gif|bmp|svg|PNG|JPE?G|GIF|BMP|JPEG|SVG)$"
