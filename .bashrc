# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
EXA=$(which exa);
if [ -n "$EXA" ]; then 
  alias ll='exa -alF'
else 
  alias ll='ls -alF'
fi
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

export BACKUP="egdod/Backup"
export TARGET=vulcan
export VIDLIB=mmzzkk
export PHOTOLIB=fodder
export MUSICLIB="/mmzzkk/Music"
export MBKS="/egdod/Backup/xMusic/"
export MARCH="/egdod/Backup/xMusic/Music_Archived"
export LH="$HOME/src/github/library-helpers"


source $LH/util.sh

# use px if available
PS=$(which px)
if ! [ -n "$PS" ]; then
  PS="ps awux |grep"
fi

function start_if_not_list() {
  running="$($PS `whoami`)"
  for i in $@; do 
    if ! stringContains "$i" "$running"; then
      $i &
    else
      echo "$i already running."
    fi
  done
}
export -f start_if_not_list

function start_if_not_args() { 
  running="$($PS `whoami`)"
  if ! stringContains "$1" "$running"; then
    $@ &
  else
    echo "$1 already running."
  fi
}
export -f start_if_not_args


# Read a single char from /dev/tty, prompting with "$*"
# Note: pressing enter will return a null string. Perhaps a version terminated with X and then remove it in caller?
# See https://unix.stackexchange.com/a/367880/143394 for dealing with multi-byte, etc.
function get_keypress {
  local REPLY IFS=
  >/dev/tty printf '%s' "$*"
  [[ $ZSH_VERSION ]] && read -rk1  # Use -u0 to read from STDIN
  # See https://unix.stackexchange.com/q/383197/143394 regarding '\n' -> ''
  [[ $BASH_VERSION ]] && </dev/tty read -rn1
  printf '%s' "$REPLY"
}
export -f get_keypress

# Get a y/n from the user, return yes=0, no=1 enter=$2
# Prompt using $1.
# If set, return $2 on pressing enter, useful for cancel or defualting
function get_yes_keypress {
  local prompt="${1:-Are you sure}"
  local enter_return=$2
  local REPLY
  # [[ ! $prompt ]] && prompt="[y/n]? "
  while REPLY=$(get_keypress "$prompt"); do
    [[ $REPLY ]] && printf '\n' # $REPLY blank if user presses enter
    case "$REPLY" in
      Y|y)  return 0;;
      N|n)  return 1;;
      '')   [[ $enter_return ]] && return "$enter_return"
    esac
  done
}
export -f get_yes_keypress

# Prompt to confirm, defaulting to YES on <enter>
function confirm_yes {
  local prompt="${*:-Are you sure} [Y/n]? "
  get_yes_keypress "$prompt" 0
}
export -f confirm_yes

export NO_ATI_BUS=1
export PYTHONPATH=/usr/lib/python3.11:/usr/lib/python3/dist-packages
function use27 {
  export PYTHONPATH=/usr/local/lib/python2.7/dist-packages
  export PATH=/usr/local/deprecated/bin:$PATH
  alias python=/usr/deprecated/bin/python2.7
}
IMGx="\\.(jpe?g|png|jpg|gif|bmp|svg|PNG|JPE?G|GIF|BMP|JPEG|SVG)$"
BLK="(home|problem|egdod|ConfSaver|headers|man|locale)"
alias grep="grep -E -v \"$BLK\"|grep -E"
alias vbp="vim $HOME/.bash_profile && source $HOME/.bash_profile"
PATH=$PATH:/home/mt/bin:/home/mt/src/github/networkmanager-dmenu:~/src/google/flutter/bin:~/src/github/eww/target/release
export D="$HOME/src/github/dots"

function restore() {
  global=0
  LOC=$1
  POSITIONAL_ARGS=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      -g|--global)
        global=1
	LOC=$2
        shift # past argument
        shift # past value
        ;;
      -h|--help)
        echo "A simple wrapper function to restore from a backup dir on a"
        echo "fresh install."
        echo " " 
        echo "-g is for global, non-personalized software from a local source"
        echo "but still restored to \$HOME."
        shift # past argument
        shift # past value
        ;;
      -*|--*)
        echo "Unknown option $1"
        return 1
        ;;
      *)
        POSITIONAL_ARGS+=("$1") # save positional arg
        shift # past argument
        ;;
    esac
  done
  set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters
  if [ $global -eq 1 ]; then 
    BK="$HOME/$TARGET/$BACKUP/Software/Linux/"
  else
    BK="$HOME/$TARGET/$BACKUP/Devices/personal/$(hostname)/$(whoami)_latest/$(whoami)"
  fi
  mounted=$(mountpoint $HOME/$TARGET);
  if [ $? -ne 0 ]; then
    $LH/mounter-t.sh
  fi
  if [ -d "$BK" ]; then
    new="$BK/$LOC"
    old="$HOME/$LOC"
    confirm_yes "restoring $new to $old... ok?"
    mkdir -p $HOME/.bak
    if [ -d "$old" ]; then 
      echo "Backing up existing $old to .bak"
      cp -vr "$old" "$HOME/.bak"
    fi
    cp -vr $new $HOME/
  else
    >&2 printf "Didn't find a backup directory at $BK. exiting."
  fi
}
export -f restore

distro="$(lsb_release -a);"
function stringContains() {
        $(echo "$2"|grep -Eqi $1);
        return $?;
}
export -f stringContains

if stringContains "arch" "$distro"; then
  alias sai="sudo pacman -Sy"
  alias sau="sudo pacman -Syu"
  alias sauu="sudo pacman -Syu"
  alias sas="yay -Ss"
  alias sar="sudo pacman -Rscn"
fi
if stringContains "(fedora|nobara)" "$distro"; then
  alias sai="sudo dnf install -y"
  alias sau="sudo dnf upgrade -y"
  alias sauu="sudo dnf upgrade -y"
  alias sas='sudo dnf search'
  alias sar="sudo dnf remove -y"
fi
if stringContains "(debian|ubuntu)" "$distro"; then
  alias sai="sudo aptitude install"
  alias sau="sudo aptitude update"
  alias sauu="sudo aptitude update && sudo aptitude upgrade"
  alias sas="sudo aptitude search"
  alias sar="sudo aptitude remove"
  alias sap='sudo aptitude purge'
  alias saar="sudo apt-add-repository"
  function saig() {
    pattern=$1
    sudo apt install *$pattern*
  }
  export -f saig
  function sarg() {
    pattern=$1
    sudo apt remove *$pattern*
  }
  export -f sarg
  function sapg {
    pattern=$1
    sudo apt purge *$pattern*
  }
  export -f sapg
  function sasi {
    pattern=$1
    sudo aptitude search $pattern|grep ^i
  }
  export -f sasi
  function sas_oldskool {
    pattern=$1
    sudo sed -i.bak 's@#deb\ http://archive@deb\ http://archive@g' /etc/apt/sources.list
    sau
    sas $i
    sudo sed -i.bak 's@deb\ http://archive@#deb\ http://archive@g'  /etc/apt sources.list
  }
  export -f sas_oldskool
  function sai_oldskool {
    pattern=$1
    sudo sed -i.bak '/archive/ s@#deb\ http://archive@deb\ http://archive@g' /etc/apt/sources.list
    sau
    sai $i
    sudo sed -i.bak '/archive/ s@deb\ http://archive@#deb\ http://archive@g'  /etc/apt sources.list
  }
  export -f sai_oldskool
fi

function wwwify () {
  sudo sed -i.bak '/www-data/ s#/usr/sbin/nologin#/bin/bash#' /etc/passwd;
  sudo -i -u www-data $@;
  sudo sed -i.bak '/www-data/ s#/bin/bash#/usr/sbin/nologin#' /etc/passwd;
}
export -f wwwify

function mastodonify () {
  sudo sed -i.bak '/mastodon/ s#/usr/sbin/nologin#/bin/bash#' /etc/passwd;
  sudo -i -u mastodon $@;
  sudo sed -i.bak '/mastodon/ s#/bin/bash#/usr/sbin/nologin#' /etc/passwd;
}
export  -f mastodonify


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
export -f hn

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
export -f symlink_child_dirs

# thats too long to type though.
alias scd="symlink_child_dirs"

alias du0="du -h --max-depth=0"
alias du1="du -h --max-depth=1"
alias ns="sudo systemctl status nginx"
alias nr="sudo systemctl restart nginx"
alias nt="wwwify nginx -t"
alias nT="sudo nginx -T"
alias di="sudo dpkg -i"
alias sdw="sudo -i -u www-data"
alias ss="sudo systemctl"
alias ssen="sudo systemctl enable"
alias ssup="sudo systemctl start"
alias ssdn="sudo systemctl stop"
alias ssr="sudo systemctl restart"
alias ssst="sudo systemctl status"
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
  f=$(echo "$url"|cut -d"/" -f1-|cut -d"." -f1)
  cd $f
}
export -f ghc

CARGO=$(which cargo);
if [ -n "$CARGO" ]; then
  source "$HOME/.cargo/env"
fi

PNPM=$(which pnpm);
if [ -n "$PNPM" ]; then
  # pnpm
  export PNPM_HOME="/home/mt/.local/share/pnpm"
  case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
  esac
  # pnpm end
fi

FIREWALLD=$(which firewall-cmd)
if [ -n "$FIREWALLD" ]; then
  function sfwp () {
    sudo firewall-cmd --add-port $1 --zone public --permanent
    sudo firewall-cmd --reload
    ssr firewalld
  }
  export -f sfwp

  function sfwrm () {
    sudo firewall-cmd --remove-port $1 --zone public --permanent
    sudo firewall-cmd --reload 
    ssr firewalld
  }
  export -f sfwrm
fi
