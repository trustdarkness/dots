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

if [[ $(uname) == "Linux" ]]; then
  source linuxutil.sh
elif [[ $(uname) == "Darwin" ]]; then
  source macutil.sh
fi

function string_contains() {
  grep -Eqi "${1:-}" <(echo "${2:-}");
  return $?;
}
alias stringContains="string_contains"

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
  f=$(echo "$url"|awk -F"/" '{print$NF}'|cut -d"." -f1)
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

function bash_minor_version() {
  echo "${BASH_VERSINFO[1]}"
}

function bash_version() {
  major=$(bash_major_version)
  minor=$(bash_minor_version)
  echo "${major}.${minor}"
}

# stolen from https://stackoverflow.com/questions/8654051/how-can-i-compare-two-floating-point-numbers-in-bash
is_first_floating_number_bigger () {
    number1="$1"
    number2="$2"

    [ ${number1%.*} -eq ${number2%.*} ] && [ ${number1#*.} \> ${number2#*.} ] || [ ${number1%.*} -gt ${number2%.*} ];
    result=$?
    if [ "$result" -eq 0 ]; then result=1; else result=0; fi

    __FUNCTION_RETURN="${result}"
}
