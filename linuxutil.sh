#!/bin/bash
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

declare -i ENXIO=6 # No such device or address
declare -i EINVAL=22 # nvalid argument
declare ARROW=$'\u27f6'

export HNB='(egdod|City|BB|Back|skins|theme|icon|locale)'
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
alias journalctl="grc journalctl"
alias journalctl_categories='journalctl --list-catalog'
alias journalctl_errplus="journalctl -p err..alert"
alias journalctl_authlog="journalctl SYSLOG_FACILITY=10"
alias diff='diff --color=auto'
export LESS='-R --use-color -Dd+r$Du+b$'

# locate with regex exclusions
function mL() {
  posregex="${1:-}"
  dHNP="$(dref "${HNP}")"
  dBLK="$(deref "${BLK}")"
  ignore="${dHNP}\|${dBLK}"
  printf -v regexstr '^/(?!%s)(%s)$' "$ignore" "$posregex"
  plocate "$regexstr"
}

function deref() {
  # sort of like a derference operator, we want to strip the outer
  # pair of whatevers off a string var in bash
  v="${1:-}"
  l="${#v}"
  echo "${v:1:-1}"
  return 0
}

# make journalctl wrap instead of truncate:
# https://wiki.archlinux.org/title/Systemd/Journal
export SYSTEMD_LESS=FRXMK

DISTRO="$(lsb_release -d 2>&1|grep -E Desc|awk -F':' '{print$2}'|xargs)"
_etc_passwd_globals() {
  _usage() {
    se "sets NOLOGIN and WEBUSER based on distro if they are not set"
    se " -r resets them, without -r if they're already set, this a noop"
    return 0
  }
  r=false
  for arg in "$@"; do
    [[ "$arg" == \-r ]] && r=true || { _usage && return 1; }
  done
  if [ -n "$NOLOGIN" ] && [ -n "$WEBUSER" ] && ! $r; then
    return 0
  fi
  if string_contains "(arch|Manjaro|endeavour)" "$DISTRO"; then
    NOLOGIN="/usr/bin/nologin"
    WEBUSER="nginx"
  elif string_contains "(Debian|Ubuntu)" "$DISTRO"; then
    NOLOGIN="/usr/sbin/nologin"
    WEBUSER="www-data"
  else
    # this tends to be different on different distros
    # TODO fix to properly detect whats already in /etc/passwd
    NOLOGIN="$(type -p nologin)"
    WEBUSER="www-data"
  fi
}

# Adds a real shell to www-data's account in /etc/password
# for the length of a sudo session, to assist in troubleshooting
# when you ctrl-d sudo, www-data goes back to /usr/bin/nologin
function wwwify () {
  _etc_passwd_globals
  sudo sed -i.bak "/$WEBUSER/ s#$NOLOGIN#/bin/bash#" /etc/passwd;
  sudo -i -u $WEBUSER $@;
  sudo sed -i.bak "/$WEBUSER/ s#/bin/bash#$NOLOGIN#" /etc/passwd;
}

function airify () {
  _etc_passwd_globals
  sudo sed -i.bak "/airsonic/ s#$NOLOGIN#/bin/bash#" /etc/passwd;
  sudo -i -u airsonic $@;
  sudo sed -i.bak "/airsonic/ s#/bin/bash#$NOLOGIN#" /etc/passwd;
}

# similar to wwwify, but for mastadon, a real shell lasting
# for the length of a sudo session, to assist in troubleshooting
# when you ctrl-d sudo, mastadon goes back to /usr/bin/nologin
# assuming i ever set it up
function mastify() {
  _etc_passwd_globals
  sudo sed -i.bak "/mastodon/ s#$NOLOGIN#/bin/bash#" /etc/passwd;
  sudo -i -u mastodon $@;
  sudo sed -i.bak "/mastodon/ s#/bin/bash#$NOLOGIN#" /etc/passwd;
}

function get_grab_events() {
  valid_mouse_devices=(
    pointer
    mouse
    "core pointer"
    "virtual core pointer"
    # are there others? touchpads? trackpoints?
  )
  valid_keyboard_devices=(
    keyboard
    'core keyboard'
    'virtual core keyboard'
  )
  allgrabs=false
  onlylastgrab=true
  metadata=false
  device=
  optspec="akmMd:h"
  unset OPTIND
  unset optchar
  while getopts "${optspec}" optchar; do
	local OPTIND
	case "${optchar}" in
	  a)
      allgrabs=true
      onlylastgrab=false
      ;;
	  M)
      metadata=true
      ;;
    d)
      devices+=("$OPTARG")
      ;;
    k)
      devices+=(keyboard)
      ;;
    m)
      device+=(mouse)
      ;;
	  h)
		usage
		return 0
		;;
	  *)
		usage
		return 1
		;;
	esac
  done

  if [ -d "$CACHE" ]; then
    xlog="/var/log/Xorg.0.log"
    luc="$CACHE/com.trustdarkness.linuxutil"
    # below guarantees dirname $dxlog exists and is writeable
    mkdir -p "$luc"; ret=$?; [ $ret -gt 0 ] && return 1
    ts=$(fsts)
    appendage_name="${FUNCNAME}_${fsts}"
    # below guarantees $xlog exists
    bn=$(basename "$xlog"); ret=$?; [ $ret -gt 0 ] && return 2
    # "destructive" xlog
    dxlog="$luc/${bn}_${appendage_name}"
    # incase we need to be destructive
    cp "$xlog" "$dxlog"; ret=$?; [ $ret -gt 0 ] && return 3
    if $onlylastgrab; then
      xloglen=$(wc -l "$xlog"|awk '{print$1}'); is_int "$xloglen" || return 4
    fi
    # lc = log command
    xdotool key "XF86LogGrabInfo"
    if ! $allgrabs; then
      dxloglen=$(wc -l "$dxlog"|awk '{print$1}'); is_int "$dxloglen" || return 6
      grabs_len=$((dxloglen-xloglen))
      grablog="$CACHE/grablog_$ts"
      tail -n $xloglen "$dxlog" > "$grablog"; [ -f "$grablog" ] || return 7  #|grep -n -m1 -A5 graba
      grabloglen=$(wc -l "$grablog"|awk '{print$1}'); is_int "$grabloglen"|| return 8
      logvars=(xloglen newxloglen grabloglen grabslen); debug
    else
      grep -A4 'grab 0x' "$dxlog"
    fi
  fi
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
  if string_contains "(arch|Manjaro|endeavour)" "$DISTRO"; then
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
    path_prepend "/usr/local/deprecated/bin"
  fi
  alias python=/usr/deprecated/bin/python2.7
}

# makes the local env use python 3.10
function use310 {
  if [ -d "/usr/deprecated/" ]; then
    if [ -f "/usr/deprecated/bin/python3.10" ]; then
      export PYTHONPATH=/usr/deprecated/lib/python3.10
      path_prepend "/usr/local/deprecated/bin"
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

_autostart_globals() {
  XDG_AUTOSTART="/etc/xdg/autostart"
  USER_AUTOSTART="$HOME/.config/autostart"
  _AUTOSTART=( "${XDG_AUTOSTART}" "${USER_AUTOSTART}" )
}

autostart-ls() {
  _usage() {
    se "autostart-ls list commands and programs set to start with session"
    se " "
    se "Args: -u user-level -s system-level -a all, both user and system"
  }
  optspec="usa:h"
  _autostart_globals
  unset OPTIND
  unset OPTARG
  unset optchar
  while getopts "${optspec}" optchar; do
    case "${optchar}" in
      u)
        dirs=( "$USER_AUTOSTART" )
        ;;
      s)
        dirs=( "$XDG_AUTOSTART" )
        ;;
      a)
        dirs=( "${_AUTOSTART[@]}" )
        ;;
      h)
        _usage; return 0
        ;;
    esac
  done
  [ -n "$dirs" ] || dirs=( "${_AUTOSTART[@]}" )
  for dir in "${dirs[@]}"; do
    for path in "${dir}"/*; do
      echo "$(basename "$(basename "$path")" .desktop)";
    done
  done
}

function autostart-disable() {
  xdg_autostart_dir="/etc/xdg/autostart/"
  disabled="/etc/xdg/disabled"
  failures=0
  for arg in "$@"; do
    local to_disable="$xdg_autostart_dir/$arg"
    if ! [ -f "$to_disable" ]; then to_disable="$to_disable.desktop"; fi
    if [ -f "$to_disable" ]; then
      echo "moving $to_disable to $disabled"
      sudo mkdir -p "$disabled"
      if ! sudo mv "$xdg_autostart_dir/$to_disable" $disabled; then
        ((failures++))
      fi
    else
      warn "could not find $to_disable in $xdg_autostart_dir"
    fi
  done
  return $failures
}

# TODO (low) fix autocomplete for loop error
# complete -W "$(autostart-ls)" xdg_disable_autostart

vlcplugins='/usr/lib/vlc/plugins'
vlcpluginsdisabled='/usr/lib/vlc/plugins.disabled'
vlcextensions='/usr/lib/vlc/lua/extensions/'

function vvlce() {
  extension_name="${1:-}"
  if [ -f "$vlcextensions/$extension_name" ]; then
    vim "$vlcextensions/$extension_name"
  else
    se "could not find $vlcextensions/$extension_name"
  fi
}

function vlc_extensions() {
  # TODO: glob
  ls "$vlcextensions"
}

function vlc_plugin_categories() {
  # TODO: glob
  ls "$vlcplugins"
}

function vlc_plugins() {
  set -x
  declare -ga categories
  categories= ; unset categories
  categories=( $(vlc_plugin_categories) )
  if [ -n "${1:-}" ]; then
    if in_array "${1:-}" "categories"; then
      categories=("${1:-}")
    fi
  fi
set +x
  for cat in "${categories[@]}"; do
    echo "$cat:"
    (for plugin in "$vlcplugins"/"$cat"/*; do
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
    if [ -f "${vlcplugins}/${to_disable}" ]; then
      bn="${to_disable}"
      to_disable="${vlcplugins}/${to_disable}"
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

# returns the best guess for the running desktop session
function whodesktop() {
  if [ -n "${DESKTOP_SESSION}" ]; then
    echo "${DESKTOP_SESSION}"
  else
    e=$(pgrep "e16")
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
  WINEARCH=win32 WINEPREFIX="/home/mt/.PlayOnLinux/wineprefix/Audio32/" wine "$@"
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

function find_ui_text() {
  likelydirs=(
    /usr/lib
    /usr/share
    /etc
    /bin
    /usr/bin
    $HOME/.config
    $HOME/.local/share
  )
  potentials=()
  for dir in "${likelydirs[@]}"; do
    grep --color -A3 -B3 --exclude=\*.o -rnw -I -e "${1:-}"
  done
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
  case $- in
    *i*)
    s['linuxutil.sh']="${s['linuxutil.sh']}+$D/kutil.sh" ;;
  esac
  skutil
}

# if we think this is plasma, load the kutil
desktop=$(whodesktop 2> /dev/null)
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
  case $- in
    *i*)
    s['linuxutil.sh']="${s['linuxutil.sh']}+$HOME/.cargo/env"
  ;; esac
    source "$HOME/.cargo/env"
  fi
fi

# load npm
PNPM=$(type -p pnpm)||true;
if [ -n "$PNPM" ]; then
  # pnpm
  export PNPM_HOME="/home/mt/.local/share/pnpm"
  case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *)
      if ! [[ "${PATH}" == *"$PNPM_HOME"* ]]; then
        path_prepend "$PNPM_HOME"
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

# TODO make pythonpath use our bash pathlib
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

# This is hard to remember the variables for without something
# like Dspy to help
function dbus_session_method_call() {
  bus_dest="${1:-}"
  interface="${2:-}"
  objectpath="${3:-}"
  method="${4:-}"
IFS='' read -r -d '' dbuscmd <<EOF
  dbus-send --session \
    --dest="${bus_dest}" \
    --type=method_call \
    --print-reply ${objectpath} \
    ${interface}.${method}
EOF
echo "$dbuscmd"
eval "$dbuscmd"
}

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

trash() {
  local path
  for path in $@; do
    if [[ "$path" == -* ]]; then :
    else
      # remove trailing slash
      local mindtrailingslash=${path%/}
      # remove preceding directory path
      local dst=${mindtrailingslash##*/}
      if [ -e "$HOME/.local/share/Trash/$dst" ]; then
        dst="${dst}_$(fsts)"
      fi
      if ! ret=$(mv "$path" "$HOME/.local/share/Trash/$dst"); then
        se "mv returned $ret on $path. aborting."
        return $ret
      fi
    fi
  done
  return 0
}

compgenv() {
  for name in $(compgen -v); do
     printf "%s=%s\n" "$name" "${!name}"
  done
  return 0
}

samepath() {
  one="${1:-}"
  two="${2:-}"
  if ! is_absolute "$one"; then
    one="$(realpath "$one")"
  fi
  if ! is_absolute "$two"; then
    two="$(realpath "$two")"
  fi
  e=(
    [0]="N/A"
    [1]="Argument one ($one) does not seem to be a valid path"
    [2]="Argument two ($two) does not seem to be a valid path"
    [3]="Both paths are mounted from the same device (%s), but dont seem to have the same path from their respective mountpoints."
    [4]="These two paths are mounted from different devices ($one from %s; $two from %s)"
  )
  ! [ -e "$one" ] && { err "${e[1]}"; return 1; }
  ! [ -e "$two" ] && { err "${e[2]}"; return 2; }
  [[ "$one" == "$two" ]] && return 0 # trivial case
  onemount="$(findmnt -n -o SOURCE --target "$one")"
  twomount="$(findmnt -n -o SOURCE --target "$two")"
  if [[ "$onemount" == "$twomount" ]]; then
    readarray -t mounts < <(findmnt -n "$onemount" -o TARGET)
    { [[ "${one/${mounts[0]}/}" == "${two/${mounts[1]}/}" ]] && return 0; } || true
    { [[ "${one/${mounts[1]}/}" == "${two/${mounts[0]}/}" ]] && return 0; } || true
    err "${e[3]}" "$onemount"
    return 3
  else
    printf -v msg "${e[4]}" "$onemount" "$twomount"
    err "$msg"
    return 4
  fi
}

safe_mount_x() {
  mnt=$1
  uuid=$2
  isLuks=false
  disk="/dev/disk/by-uuid/$uuid"
  if sudo cryptsetup isLuks "$disk"; then isLuks=true; fi
  if isLuks; then mapped="/dev/mapper/luks-$uuid"; fi
  mounted=$(mountpoint $mnt);
  if [ $? -ne 0 ]; then
    if $isLuks; then
      udisksctl unlock -b $disk
      sleep 2
      sudo mount "$mapped" "$mnt"
    else
      sudo mount "$disk" "$mnt"
    fi
  fi
}

# mentined on forums as a type of reset, this is an explicit way given by
# kernel developers for a user to deauthorize certain devices.  This
# function forces a device to reset by deauthing and then reauthing the
# device's connection
function usb_device_deauthorize_reset_by_vendor_prod() {
  local vendor="${1:-}"
  local product="${2:-}"
  usb_deauth_device "$vendor" "$product"
  sleep 0.5
  usb_auth_device "$vendor" "$product"
}

function usb_deauth_device() {
  local vendor="${1:-}"
  local product="${2:-}"
  local quiet="${3:-false}"
  usb_device_push_authorization_value "${vendor}" "${product}" "0" "$quiet"
  return $?
}

function usb_auth_device() {
  local vendor="${1:-}"
  local product="${2:-}"
  local quiet="${3:-false}"
  usb_device_push_authorization_value "${vendor}" "${product}" "1" "$quiet"
  return $?
}

# https://www.kernel.org/doc/html/latest/usb/authorization.html
function usb_device_push_authorization_value() {
  local vendor="${1:-}"
  local product="${2:-}"
  local auth="${3:-}"
  local quiet="${4:-true}"
  declare -ga found=()
  usage() {
    cat <<-'EOF'
usb_device_push_authorization_value - sets authorization value for usb device

Positional Args:
  vendor = 4 digit hex value representing device vendor
  product = 4 digit hex value representing device product
  auth = 0 - deauthorizes any devices with this vendor:product from interfacing
             with usb on this system
         1 - authorizes vendor:product devices on this system
         2 - authorize by default only devices connected to internal USB ports
  quiet = true|false whether to print status to console

Returns:
  0 on success
  EINVAL=22 # nvalid argument on malformed args
  ENXIO=6 # No such device or address if no devices found
EOF
  }
  if ! [[ "${vendor}" =~ [0-9A-Fa-f]{4} ]] ||
    ! [[ "${product}" =~ [0-9A-Fa-f]{4} ]]; then
    se "vendor or product string malformed"
    usage
    return $EX_USAGE
  fi
  if ! in_between_inclusive "$auth" "0" "2"; then
    se "auth must be 0, 1, or 2"
    usage
    return $EX_USAGE
  fi
  for DIR in $(find /sys/bus/usb/devices/ -maxdepth 1 -type l); do
    if [[ -f $DIR/idVendor && -f $DIR/idProduct &&
          $(cat $DIR/idVendor) == $VENDOR && $(cat $DIR/idProduct) == $PRODUCT ]]; then
            found+=( "${DIR}" )
            echo "$auth" > "$DIR/authorized"
    fi
  done

  if [ "${#found[@]}}" -gt 0 ]; then
    if ! "$quiet"; then
      se "Set authorization to $auth for these devices:"
      for device_dir in "${found[@]}"; do
        se "$ARROW $device_dir"
      done
    fi
    return 0
  else
    if ! "$quiet"; then
      se "No devices found with vendor:product ${vendor}:${product}"
    fi
    return "$ENXIO"
  fi
}

# https://askubuntu.com/questions/645/how-do-you-reset-a-usb-device-from-the-command-line
function usb_ports_reset_all() {
  for i in /sys/bus/pci/drivers/[uoex]hci_hcd/*:*; do
    [ -e "$i" ] || continue
    sudo sh -c "echo \"${i##*/}\" > \"${i%/*}/unbind\""
    sudo sh -c "echo \"${i##*/}\" > \"${i%/*}/bind\""
  done
}

function usb_controller_reset() {
  echo -n "0000:00:1a.0" | tee /sys/bus/pci/drivers/ehci_hcd/unbind
  echo -n "0000:00:1d.0" | tee /sys/bus/pci/drivers/ehci_hcd/unbind
  echo -n "0000:00:1a.0" | tee /sys/bus/pci/drivers/ehci_hcd/bind
  echo -n "0000:00:1d.0" | tee /sys/bus/pci/drivers/ehci_hcd/bind
}

function usb_drivers_reset:() {
  # USB drivers
  rmmod xhci_pci
  rmmod ehci_pci

  # uncomment if you have firewire
  #rmmod ohci_pci

  modprobe xhci_pci
  modprobe ehci_pci

  # uncomment if you have firewire
  #modprobe ohci_pci
}


function diskinfo() {
  # TODO: consider adding modes for different utilities info, i.e.
  # https://serverfault.com/questions/190685/whats-the-best-way-to-get-info-about-currently-unmounted-drives#
  # lshw -class disk
  # sfdisk -l
  # lsscsi --scsi_id
  # fdisk -l
  # parted -l
  # find -L /sys/bus/scsi/devices
  # more for individual disks, particularly
  # hdparm -I <disk>
  # lsscsi (for rescan location)
  if [ -n "${1:-}" ]; then
    smartctl -ix "${1:-}"
  else
    grc lsblk -s -M -t -o NAME,FSTYPE,LABEL,FSSIZE,FSAVAIL,FSUSE%,TRAN,MOUNTPOINTS
  fi
}
