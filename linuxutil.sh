#!/usr/local/env bash
# This file is sourced from util.sh if that file is sourced on 
# a linux box, after which it can be easily edited and resourced
# by running vosutil or simply resourced by running sosutil, as 
# it is the os (specific) util.  There's a corresponding mac version
# Expects the following globals to be in env:
# TARGET - generally the remote system where backups are kept
# BACKUP - relative path on that system to the root of the backup
#          usually mouted over sshfs
# BLK - an egrep compatible regex used as a blocilist to sift out
#       noise on local filesystem searches piping locate through 
#       the dubious mgrep
# LH - path to the root of the library_helpers repo (only used in 
#      the alias below, nothing will break)
# D - path to the root of the dots repo
# Other globals are handled internally if they're not present.  
# This file may also rely on functions and globals available in 
# .bashrc (where util.sh is sourced from) amd existence.sh (also
# sourced from .bashrc)
export BLK="(home|problem|egdod|ConfSaver|headers|man|locale|themes|icons)"
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
alias sstat="sudo systemctl status"
alias sglobals="source $HOME/.globals"
alias globals="vimcat $HOME/.globals"
alias mgrep="grep -E -v \"$BLK\"|grep -E"
alias slhu="source $LH/util.sh"
alias vbp="vim $HOME/.bash_profile && source $HOME/.bash_profile"

mkdir -p /tmp/mpvsockets

# .globals is a symlink to the copy in the repo
# for some reason, I did it that way instead of sourcing from
# the repo directly.  Perhaps someday I will either remember
# and update this comment or fix it.
if ! declare -p "GH" > /dev/null 2>&1; then
  source "$HOME/.globals"
fi
if ! declare -F "start_if_not_list" > /dev/null 2>&1; then
  source "$D/conditional_starters.sh"
fi

distro="$(lsb_release -d 2>&1|grep -E Desc|awk -F':' '{print$2}'|xargs)"
if string_contains "(arch|Manjaro|endeavour)" "$distro"; then
  nologin="/usr/bin/nologin"
  webuser="nginx"
elif string_contains "(Debian|Ubuntu)" "$distro"; then
  nologin="/usr/sbin/nologin"
  webuser="www-data"
else
  # this tends to be different on different distros
  # TODO fix to properly detect whats already in /etc/passwd
  nologin="$(type -p nologin)"
  webuser="www-data"
fi

# Adds a real shell to www-data's account in /etc/password 
# for the length of a sudo session, to assist in troubleshooting
# when you ctrl-d sudo, www-data goes back to /usr/bin/nologin
function wwwify () {
  sudo sed -i.bak "/$webuser/ s#$nologin#/bin/bash#" /etc/passwd;
  sudo -i -u $webuser $@;
  sudo sed -i.bak "/$webuser/ s#/bin/bash#$nologin#" /etc/passwd;
}

function airify () {
  sudo sed -i.bak "/airsonic/ s#$nologin#/bin/bash#" /etc/passwd;
  sudo -i -u airsonic $@;
  sudo sed -i.bak "/airsonic/ s#/bin/bash#$nologin#" /etc/passwd;
}

# similar to wwwify, but for mastadon, a real shell lasting  
# for the length of a sudo session, to assist in troubleshooting
# when you ctrl-d sudo, mastadon goes back to /usr/bin/nologin
# assuming i ever set it up
function mastify() {
  sudo sed -i.bak "/mastodon/ s#$nologin#/bin/bash#" /etc/passwd;
  sudo -i -u mastodon $@;
  sudo sed -i.bak "/mastodon/ s#/bin/bash#$nologin#" /etc/passwd;
}

# tries to kill major gui processes to force X11 to restart
function guikiller() {
  keywords="xfce kde plasma kwin"
  for alive in $keywords; do 
    pkill -i $alive
  done
}

function live_chroot() {
  mountpoint="${1:-/mnt}"
  if ! [ -d "$mountpoint/boot" ]; then 
    echo "$moutpoint/boot doesn't exist, check your mounts"
    return 1
  fi
  efi=$(ls "$mountpoint/boot/efi")
  if [ -z "$efi" ]; then 
    echo "$mountpoint/boot/efi seems to be empty, check your mounts"
  fi

  for i in /dev /dev/pts /proc /sys /run; do sudo mount -B $i ${mountpoint}$i; done 
  distro="$(lsb_release -d 2>&1|grep -E Desc|awk -F':' '{print$2}'|xargs)"
  if string_contains "(arch|Manjaro|endeavour)" "$distro"; then
    if ! type -p arch-chroot > /dev/null 2>&1; then 
      sudo pacman -Sy arch-install-scripts
      sudo arch-chroot "$mountpoint"
    fi
  else
    sudo chroot "$mountpoint"
  fi
}

# yes, i know, i know, 2.7?  but sometimes you need it
function use27 {
  export PYTHONPATH="/usr/local/lib/python2.7/dist-packages:/usr/deprecated/lib/python2.7/"
  if ! [[ "${PATH}" == *"/usr/local/deprecated/bin"* ]]; then
    export PATH="/usr/local/deprecated/bin:$PATH"
  fi
  alias python=/usr/deprecated/bin/python2.7
}

# makes the local env use python 3.10
function use310 {
  if [ -d "/usr/deprecated/" ]; then 
    if [ -f "/usr/deprecated/bin/python3.10" ]; then 
      export PYTHONPATH=/usr/deprecated/lib/python3.10
      export PATH=/usr/local/deprecated/bin:$PATH
      alias python=/usr/deprecated/bin/python3.10
      alias python3=/usr/deprecated/bin/python3.10
    else
      se "no python3.10 in deprecated"
    fi
  else
    se "no /usr/deprecated"
  fi
}

# Shows you the contents of all the xdg data-dirs
function sublist_xdg_data_dirs() {
  IFS=$':'; for dir in $XDG_DATA_DIRS; do ls $dir; done
}

function xdg_disable_autostart() {
  to_disable=${1:-}
  xdg_autostart_dir="/etc/xdg/autostart/"
  disabled="/etc/xdg/disabled"

  if [ -f "$xdg_autostart_dir/$to_disable" ]; then 
    echo "moving $to_disable to $disabled"
    sudo mkdir -p "$disabled"
    sudo mv $xdg_autostart_dir/$to_disable $disabled
    code=$?
    if [ $code -gt 0 ]; then 
      se "mv failed code $code"
      return $code
    fi
    return 0
  else
    echo "could not find $to_disable in $xdg_autostart_dir"
    return 1
  fi
}

_xdg_autocomplete() {
local cur
    cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $(compgen -f /etc/xdg/autostart/$cur | cut -d"/" -f5 ) )
    }
   complete -o filenames -F _xdg_autocomplete xdg_disable_autostart


vlcplugindir='/usr/lib/vlc/plugins'
vlcpluginsdisabled='/usr/lib/vlc/plugins.disabled'

function vlc_extensions() {
  ls /usr/lib/vlc/lua/extensions/
}

function vlc_plugin_categories() {
  ls "$vlcplugindir"
}

function vlc_plugins() {
  for cat in $(vlc_plugin_categories); do 
    echo "$cat:"
    (for plugin in "$vlcplugindir"/"$cat"/*; do 
      echo "  $(basename $plugin)"
    done) | column
    echo
  done
  disabled="$vlcpluginsdisabled/*"
  if [ -n "$disabled" ]; then 
    echo "disabled:"
    (for plugin in $disabled; do 
      echo "  $(basename $plugin)"
    done) |column
  fi
}

function vlc_plugin_disable() {
  to_disable="${1:-}"

  if ! [ -f "$to_disable" ]; then 
    # assume we got a basename
    if [ -f "${vlcplugindir}/${to_disable}" ]; then
      bn="${to_disable}" 
      to_disable="${vlcplugindir}/${to_disable}"
    else
      return 1
    fi
  else
    bn=$(basename "$to_disable")
  fi
  sudo mkdir -p "$vlcpluginsdisabled"
  if ! sudo mv "$to_disable" "$vlcpluginsdisabled"; then 
    ret=$?
    se "err $ret: sudo mv $to_disable $vlcpluginsdisabled"
    return $ret
  fi
  return 0    
}

# if firewalld is installed, give us some helper funcs 
# for it.  if this gets any longer, it should move to its
# own, loaded on demand, helper library
FIREWALLD=$(type -p firewall-cmd)
if [ -n "$FIREWALLD" ]; then
  function sfwp () {
    local input="${1:-}"
    if [ -n "${input}" ]; then 
      if [[ "${input}" =~ ^[0-9]*\/tcp|udp ]]; then
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
      if [[ "${input}" =~ ^[0-9]*\/tcp|udp ]]; then
        sudo firewall-cmd --remove-port $1 --zone public --permanent
        sudo firewall-cmd --reload 
        ssr firewalld
      fi
    fi
    >&2 printf "Please specify port/protocol like 22/tcp"
    return 1
  }
fi

# returns the best guess for the running desktop session
function whodesktop() {
  if [ -n "${DESKTOP_SESSION}" ]; then 
    echo "${DESKTOP_SESSION}"
  else
    e=$PS "e16"
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
  export WINEARCH=win64
  wine64 $@
}

function p64winetricks() {
  WINEPREFIX="/home/mt/.local/share/wineprefixes/p64" WINEARCH=win64 winetricks $@
}

function wswineinstall() {
  WINEPREFIX="/home/mt/.wine-sucks/drive_c/"
  # this is stupid
  DRIVEC="/home/mt/.wine-sucks/drive_c/drive_c/"
  TMP="/home/mt/.wine-sucks/drive_c/drive_c/users/mt/Temp/"
  WINEARCH="win64"
  WINEBIN=$(type -p wine64)
  no_cd() {
    se "could not cd to drive_c : $DRIVEC"
    return 1
  }
  swd="$(pwd)"
  cd "$DRIVEC" || no_cd
  if [ -f "$1" ]; then
    se "copying $1 to $TMP for runtime consistency" 
    cp "$1" "$TMP"
    bn_src=$(basename "$1")
    printf -v path_dst "%s/%s" "$TMP" "$bn_src"
    if ! [ -f "$path_dst" ]; then 
      se "copy failed, executing original command as entered"
      se "WINEPREFIX=\"$WINEPFX\" WINEARCH=\"$WINEARCH\" $WINEBIN $@"
      se "..."
      $WINEBIN $@
      retval="$?"
    else
      shift
      WINEPREFIX="/home/mt/.wine-sucks/drive_c/" WINEARCH=win64 $WINEBIN "$path_dst" $@
      retval="$?"
    fi
  else
    se "no src bin, executing original command as entered"
    se "WINEPREFIX=\"$WINEPFX\" WINEARCH=\"$WINEARCH\" $WINEBIN $@"
    se "..."
    $WINEBIN $@
    retval="$?"
  fi
  cd "$swd" || return "$retval"
  return "$retval"
}

function wswinetricks() {
  WINEPREFIX="/home/mt/.wine-sucks/drive_c/" WINEARCH=win64 winetricks $@
}

# TODO: generalize options
function swapfile1Gtemp() {
  ts=$(fsts)
  sudo dd if=/dev/zero of=/tmp/swapfile${ts} bs=1024 count=1048576
  sudo chmod 600 /tmp/swapfile${ts}
  sudo chmod 600 /tmp/swapfile${ts}
  sudo mkswap /tmp/swapfile${ts}
  sudo swapon /tmp/swapfile${ts}
}

# of course, there are many more than this, but these should be sufficient for
# purposes like system migration
fontdirs=(
  "/CityInFlames/mt/.local/share/fonts"
  "/usr/share/fonts"
)

function fontsinstalluser() {
  fontinstalled() {
    basename="${1:-}"
    # TODO: check system font dirs as well
    num_found=$(find "$HOME/.fonts" -iname "*$basename" | wc -l)
    if gt "$num_found" 0; then 
      return 0
    fi
    return 1
  }

  install_ctr=0
  exists_ctr=0
  error_ctr=0
  declare -a foundfonts
  while IFS= read -r -d $'\0'; do
    foundfonts+=("$REPLY") # REPLY is the default
  done < <(find . -regextype posix-egrep -regex '(.*.otf|.*.ttf)' -print0 2> /dev/null)
  for fontpath in "${foundfonts[@]}"; do 
    bn=$(basename "$fontpath")
    if ! fontinstalled "$bn"; then
      if cp -r "$fontpath" "$HOME/.fonts"; then 
        se "installed $bn to ~/.fonts"
        ((install_ctr++))
      else
        se "error $? installing $bn to ~/.fonts"
        ((error_ctr++))
      fi
    else
      ((exists_ctr++))
    fi
  done
  bold=$(tput bold)
  normal=$(tput sgr0)
  >&2 printf "${bold}Summary -- ${normal}"
  if gt "$install_ctr" 0; then 
    >&2 printf "new fonts installed: ${bold}%d ${normal}" "$install_ctr"   
  fi
  if gt "$exists_ctr" 0; then 
    >&2 printf "skipped (already installed): ${bold}%d ${normal}" "$exists_ctr"
  fi
  if gt "$error_ctr" 0; then
    >&2 printf "failed: ${bold}%d ${normal}\n" "$error_ctr"
    return $error_ctr
  fi  
  >&2 printf "\n"
  return 0
}

# some useful aliases for kde plasma
alias skutil="source $D/kutil.sh"
alias vkutil="vim $D/kutil.sh && skutil"

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
  skutil
}

# if we think this is plasma, load the kutil
desktop=whodesktop 2> /dev/null
if [[ "$desktop" == "plasma" ]]; then 
  k
fi

# load cargo
CARGO=$(type -p cargo);
if [ -n "$CARGO" ]; then
  if ! string_contains "cargo" "$PATH"; then 
    path_append "$HOME/.cargo/bin"
  fi
  if [ -f "$HOME/.cargo/env" ]; then 
    source "$HOME/.cargo/env"
  fi
fi

# load npm
PNPM=$(type -p pnpm);
if [ -n "$PNPM" ]; then
  # pnpm
  export PNPM_HOME="/home/mt/.local/share/pnpm"
  case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *)
      if ! [[ "${PATH}" == *"$PNPM_HOME"* ]]; then 
        export PATH="$PNPM_HOME:$PATH" 
      fi
      ;;
  esac
  # pnpm end
fi

# setup the env for it and load localback
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

# disable the accessibility bus... there are some other weird
# things i did to make this stick.  maybe ill remember to document
# them the next time i reimage a box :(
#export NO_ATI_BUS=1

if [[ "${PYTHONPATH}" != "*.local/sourced*" ]]; then
  export PYTHONPATH="$PYTHONPATH:/usr/lib/python3.11:/usr/lib/python3/dist-packages:$HOME/.local/sourced"
fi

# 20240923 .bashrc sets PATH="$HOME/bin:$HOME/.local/bin:/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin$HOME/Applications:/usr/sbin:$PATH:$HOME/.local/sourced"
if [[ "${PATH}" != *"$HOME/src/google/flutter/bin"* ]]; then 
  path_append "$HOME/src/google/flutter/bin"
fi
if [[ "${PATH}" != *"$HOME/src/github/eww/target/release"* ]]; then 
  path_append "$HOME/src/github/eww/target/release"
fi

function dbus_session_services() {
  # https://stackoverflow.com/questions/19955729/how-to-find-methods-exposed-in-a-d-bus-interface
  dbus-send --session \
    --dest=org.freedesktop.DBus \
    --type=method_call \
    --print-reply /org/freedesktop/DBus \
    org.freedesktop.DBus.ListNames
}

function dbus_system_services() {
  # https://stackoverflow.com/questions/19955729/how-to-find-methods-exposed-in-a-d-bus-interface
  dbus-send --system \
    --dest=org.freedesktop.DBus \
    --type=method_call \
    --print-reply /org/freedesktop/DBus \
    org.freedesktop.DBus.ListNames
}

function dbus_session_service_info() {
  service=${1:-please provide a service name like org.freedesktop.name}
  echo "service: $service"
  slashes=$(echo "/$service" | sed 's@\.@\/@g')
  stem="${service%*.}"
  echo "service: $service slashes: $slashes stem: $stem"
  local IFS=$'\n'
  for item in $(qdbus "$service"); do
    path="$item" #intentionally only saving the last one
  done
  declare -a available
  declare -a typesigs
  available=()
  typesigs=()
  for line in $(qdbus "$service" "$path"); do 
    type=$(echo "$line"|awk '{print$1}')
    
    if [[ "$type" == "property" ]]; then 
      returntype=$(echo "$line"|awk '{print$3}')
      writeable=$(echo "$line"|awk '{print$2}')
      objname=$(echo "$line"|awk '{$1=$2=$3=""; print$0}')
      printf -v typesig "%s,%s,%s" "$type" "$returntype" "$writeable"
    else
      returntype=$(echo "$line"|awk '{print$2}')
      objname=$(echo "$line"|awk '{$1=$2=""; print$0}')
      printf -v typesig "%s,%s" "$type" "$returntype"
    fi
    available+=("$objname")
    typesigs+=("$typesig")
  done
  echo "Available objects to explore in $service $path are:"
  echo "---------------------------------------------------"
  echo
  if ! [ "${#typesigs[@]}" -eq "${#available[@]}" ]; then 
    se "data retrieval error, typesigs and available differently sized"
    return 1
  fi
  ctr=0
  printf "%15s %10s %20s %s" "type" "return" "writeable" "name" |column
  for typesig in "${typesigs[@]}"; do
    type=$(echo "$typesig"|cut -d ',' -f 1)
    returntype=$(echo "$typesig"|cut -d',' -f2)
    if [[ "$type" == "property" ]]; then
      writeable=$(echo "$typesig"|cut -d ',' -f 3)
    else
      writeable="--"
    fi
    printf "%15s %10s %20s %s"  "$type" "$writeable" "$returntype" "${available[$ctr]}" |column
    ((ctr++))
  done
  # dbus-send --session --type=method_call --print-reply \
	#   --dest="$service" \
	#   $slashes \
  #   $stem.Introspectable.Introspect
}
    #org.freedesktop.Secret.Service.GetAll
	  #org.freedesktop.DBus.Introspectable.Introspect


function dbus_search() {
  for service in $(qdbus "${1:-}"); do
    echo "* $service"
    for path in $(qdbus "$service"); do 
      echo "** $path"
      for item in $(qdbus "$service" "$path"); do 
        echo "- $item"
      done
    done
  done
}
 

	
