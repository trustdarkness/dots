#!env bash
alias du0="du -h --max-depth=0"
alias du1="du -h --max-depth=1"
alias ns="sudo systemctl status nginx"
alias nr="sudo systemctl restart nginx"
alias nt="wwwify nginx -t"
alias nT="sudo nginx -T"
alias sdw="sudo -i -u www-data"
alias ss="sudo systemctl"
alias ssen="sudo systemctl enable"
alias ssup="sudo systemctl start"
alias ssdn="sudo systemctl stop"
alias ssr="sudo systemctl restart"
alias ssst="sudo systemctl status"
alias sglobals="source $HOME/.globals"
alias globals="vimcat $HOME/.globals"
alias mgrep="grep -E -v \"$BLK\"|grep -E"
alias slhu="source $LH/util.sh"
alias vbp="vim $HOME/.bash_profile && source $HOME/.bash_profile"

# .globals is a symlink to the copy in the repo
# for some reason, I did it that way instead of sourcing from
# the repo directly.  Perhaps someday I will either remember
# and update this comment or fix it.
source $HOME/.globals
source $LH/util.sh
source $MTEBENV/.conditional_starters

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
  IFS=$':'; for dir in $XDG_DATA_DIRS; do ls $dir; done
}

fwd=$(type -p firewall-cmd)
if [ -n "$FIREWALLD" ]; then
  function sfwp () {
    local input="${1:-}"
    if [ -n "${input}" ]; then 
      if [[ "${input}" =~ '^[0-9]*\/tcp|udp' ]]; then
        sudo $fwd --add-port "${input}" --zone public --permanent
        sudo $fwd --reload
        ssr firewalld
        return 0
      fi
    fi
    >&2 printf "Please specify port/protocol like 22/tcp"
    return 1
  }

  function sfwrm () {
    local input="${1:-}"
    if [ -n "${input}" ]; then 
      if [[ "${input}" =~ '^[0-9]*\/tcp|udp' ]]; then
        sudo firewall-cmd --remove-port $1 --zone public --permanent
        sudo firewall-cmd --reload 
        ssr firewalld
      fi
    fi
    >&2 printf "Please specify port/protocol like 22/tcp"
    return 1
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

function wine32in64 {
  unset WINEARCH && wine64 $@
}

function p32wine() {
  WINEARCH=win32 WINEPREFIX="/home/mt/.local/share/wineprefixes/p32" WINE=/bin/wine64 /bin/wine64 $@
}

function p32winetricks() {
  WINEPREFIX="/home/mt/.local/share/wineprefixes/p32" WINEARCH=win32 WINE=/bin/wine64 winetricks $@
}

pola32wine() {
  WINEARCH=win32 WINEPREFIX="/home/mt/.PlayOnLinux/wineprefix/Audio32/" wine $@
}

pola32winetricks() {
  WINEARCH=win32 WINEPREFIX="/home/mt/.PlayOnLinux/wineprefix/Audio32/" winetricks $@
}

function p64wine() {
  export WINEPREFIX="/home/mt/.local/share/wineprefixes/p64"
  export Winearch=win64
  wine64 $@
}

function p64winetricks() {
  WINEPREFIX="/home/mt/.local/share/wineprefixes/p64" WINEARCH=win64 winetricks $@
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

export OLDSYS="$HOME/$TARGET/$BACKUP/Software/Linux/"
export OLDHOME="$HOME/$TARGET/$BACKUP/Devices/personal/$(hostname)/$(whoami)_latest/$(whoami)"
function b() {
  source $D/localback.sh
}

function thunar_add_send_to_dest() {
  local new_dest="${1:-}"
  if ! [ -f "${new_dest}" ]; then 
    echo "${new_dest} doesn't seem to exist, would you like to create it?"
    if confirm_yes "Y/n:"; then 
      if not mkdir -p "${new_dest}"; then 
        se "mkdir -p ${new_dest} failed with $?"
        return 1
      fi
    else
      se "exiting."
      return 0
    fi
  fi 
  local bn=$(basename "${new_dest}")
  cat << EOF > "$D/.local/share/Thunar/sendto/${bn}.desktop"
[Desktop Entry]
Type=Application
Version=0.1
Enoding=UTF-8
Exec=cp %F "${new_dest}"
Icon=folder-documents
Name="${bn}"
EOF
}

export NO_ATI_BUS=1
export PYTHONPATH=/usr/lib/python3.11:/usr/lib/python3/dist-packages
export BLK="(home|problem|egdod|ConfSaver|headers|man|locale)"
export PATH=$HOME/bin:$HOME/Applications:$HOME/src/github/networkmanager-dmenu:$HOME/src/google/flutter/bin:$HOME/src/github/eww/target/release:/usr/sbin:/sbin:$PATH
