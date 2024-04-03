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

function guikiller() {
  keywords="xfce kde plasma kwin"
  for alive in $keywords; do 
    pkill -i $alive
  done
}

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

function whodesktop() {
  if [ -n "${DESKTOP_SESSION}" ]; then 
    echo "${DESKTOP_SESSION}"
  else
    e=$($PS "e16")
    r=$?
    if $r; then
      # sometimes e16 isn't able to set this up on its own
      # for reasons which remain unknown
      DESKTOP_SESSION="e16_session";
    else
      >&2 printf "DESKTOP_SESSION is empty and no \$PS e16"
    fi
  fi
}

function i() {
  source $D/installutil.sh
}

function k() {
  case "${1}" in 
    "-q")
      export QT_QPA_PLATFORMTHEME="qt5ct"
      ;;
    "-k")
      export QT_QPA_PLATFORMTHEME="kvantum"
      ;;
    "-g")
      export QT_QPA_PLATFORMTHEME="gtk2"
      ;;

  esac
  source $D/kutil.sh
}

export PATH=$HOME/bin:$HOME/Applications:$HOME/src/github/networkmanager-dmenu:$HOME/src/google/flutter/bin:$HOME/src/github/eww/target/release:/usr/sbin:/sbin:$PATH
