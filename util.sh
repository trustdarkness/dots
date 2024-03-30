function stringContains() {
        $(echo "$2"|grep -Eqi $1);
        return $?;
}
export -f stringContains

function wwwify () {
  sudo sed -i.bak '/www-data/ s#/usr/sbin/nologin#/bin/bash#' /etc/passwd;
  sudo -i -u www-data $@;
  sudo sed -i.bak '/www-data/ s#/bin/bash#/usr/sbin/nologin#' /etc/passwd;
}

function mastodonify () {
  sudo sed -i.bak '/mastodon/ s#/usr/sbin/nologin#/bin/bash#' /etc/passwd;
  sudo -i -u mastodon $@;
  sudo sed -i.bak '/mastodon/ s#/bin/bash#/usr/sbin/nologin#' /etc/passwd;
}

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

function guikiller() {
  keywords="xfce kde plasma kwin"
  for alive in $keywords; do 
    pkill -i $alive
  done
}

function symlink-child-dirs () {
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

function use27 {
  export PYTHONPATH=/usr/local/lib/python2.7/dist-packages:/usr/deprecated/lib/python2.7/
  export PATH=/usr/local/deprecated/bin:$PATH
  alias python=/usr/deprecated/bin/python2.7
}
function use310 {
  export PYTHONPATH=/usr/deprecated/lib/python3.10
  export PATH=/usr/local/deprecated/bin:$PATH
  alias python=/usr/deprecated/bin/python3.10
  alias python3=/usr/deprecated/bin/python3.10
}

function sublist-xdg-data-dirs() {
  IFS=":"; for dir in $XDG_DATA_DIRS; do ls $dir; done
}

FIREWALLD=$(which firewall-cmd)
if [ -n "$FIREWALLD" ]; then
  function sfwp () {
    sudo firewall-cmd --add-port $1 --zone public --permanent
    sudo firewall-cmd --reload
    ssr firewalld
  }


  function sfwrm () {
    sudo firewall-cmd --remove-port $1 --zone public --permanent
    sudo firewall-cmd --reload 
    ssr firewalld
  }

fi