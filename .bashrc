#!/usr/local/bin/bash
# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# avoid prepending path if our changes are already there
if [[ "${PATH}" != "*.local/bin*" ]]; then
  export PATH="$HOME/bin:$HOME/.local/bin:$HOME/Applications:/usr/local/bin:/bin:/usr/bin:/usr/sbin:$PATH"
fi

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

# some more ls aliases
if type exa >/dev/null 2>&1; then
  alias ll='exa -alF'
else 
  alias ll='ls -alF'
fi
alias la='ls -A'
alias l='ls -CF'

# breadcrumbs... for tearfree cross platform setup: 
function powerline_bootstrap() {
  if type pipx >/dev/null 2>&1; then 
    pipx install powerline-status
    mkdir -p .local/share/powerline  
    ln -is $(locate powerline.sh |grep bash) $HOME/.local/share/powerline/
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

function setcompletion() {
  if [[[ $(uname) == 'Darwin' ]]; then
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
    if ! type -p _init_completion; then 
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

if [ -z "${DEBUG}" ]; then 
  powerline_init
fi

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

export IMGx="\\.(jpe?g|png|jpg|gif|bmp|svg|PNG|JPE?G|GIF|BMP|JPEG|SVG)$"
export D="$HOME/src/github/dots"
source $D/util.sh
