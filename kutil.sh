#!/usr/bin/env bash
#
#QT_STYLE_OVERRIDE=
#QT_QPA_PLATFORMTHEME=qt5ct

kde_theme_paths=(
  "$HOME/.local/share/aurorae/themes/"
  "$HOME/.local/share/plasma/look-and-feel"
  "$HOME/.local/share/plasma/desktoptheme"
  "$HOME/.themes"
  "$HOME/.local/share/icons"
  "/usr/share/sddm/themes/"
)

function qdbus_detect_and_install() {
  if ! type -p qdbus-qt5 2>&1 > /dev/null; then
    if ! is_function qdbus_bootstrap; then
      util_env_load -b
    fi
    qdbus_bootstrap
  fi
}

function klipper_get_history() {
  qdbus org.kde.klipper /klipper org.kde.klipper.klipper.getClipboardHistoryMenu
}

function klogout() {
  qdbus_detect_and_install
  shutdown_confirm=0 # 0 no, 1 yes, -1 default
  shutdown_type=0 # 0 logout, 1 reboot, 2 halt, 3 logout, -1 default
  shutdown_mode=2 # 0 schedule, 1 try now, 2 force now, 3 interactive, -1 default
  qdbus-qt5 org.kde.ksmserver /KSMServer logout $shutdown_confirm $shutdown_type $shutdown_mode

}

function konsession() {
  qdbus_detect_and_install
  qdbus $KONSOLE_DBUS_SERVICE $KONSOLE_DBUS_SESSION
}

function konwindow() {
  qdbus_detect_and_install
  qdbus $KONSOLE_DBUS_SERVICE $KONSOLE_DBUS_WINDOW
}

function kontd() {
  qdbus_detect_and_install
  PROFILE="td.profile"
  for instance in $(qdbus | grep org.kde.konsole); do
    for session in $(qdbus "$instance" | grep -E '^/Sessions/'); do
      qdbus "$instance" "$session" org.kde.konsole.Session.setProfile "$PROFILE"
    done
  done
}


function vimkp() {
  name="${1:-Please provide a name for an existing (or new) profile}"
  vim "$HOME/.local/share/konsole/${name}.profile"
}

alias skprofile="konsession setProfile td"
alias vkprofile="vim .local/share/konsole/td.profile && skprofile"

function list_kwin_commands() {
  qdbus_detect_and_install
  for service in $(qdbus "org.kde.*"); do
    echo "* $service"
    for path in $(qdbus "$service"); do
      echo "** $path"
      for item in $(qdbus "$service" "$path"); do
        echo "- $item"
      done
    done
  done
}

function killkactivity() {
  # cache sudo
  runnning=$(sudo $PS kactivitymanagerd)
  if ! [ -n "$running"]; then
    echo "kactivitymanagerd doesn't seem to be running.  Exiting."
    return 0
  fi
  echo "TO banish kactiviymanagerd, we will try the following trickery:"
  echo "
  pkill -9 kactivitymanag
  rm -r ~/.local/share/kactivitymanagerd &&
  touch ~/.local/share/kactivitymanagerd &&
  sudo chmod -x /usr/lib/x86_64-linux-gnu/libexec/kactivitymanagerd &&
  sudo chmod -x /usr/lib/x86_64-linux-gnu/qt5/plugins/kactivitymanagerd"

  confirm_yes "OK?"
  # pkill: pattern that searches for process name longer than 15 characters will result in zero matchess
  pkill -9 kactivitymanag
  rm -r ~/.local/share/kactivitymanagerd &&
  touch ~/.local/share/kactivitymanagerd &&
  sudo chmod -x /usr/lib/x86_64-linux-gnu/libexec/kactivitymanagerd &&
  sudo chmod -x /usr/lib/x86_64-linux-gnu/qt5/plugins/kactivitymanagerd
}

function get_toolbars_and_actions() {
  if [[ "$TAG_NAME" == *"Toolbar" ]] ; then
    eval local $ATTRIBUTES
    echo "name $name"
    if [[ $TAG_NAME = "Action" ]] ; then
      eval local $ATTRIBUTES
      echo "Action name: $name"
    fi
  fi
}

function kxmlgui_parse() {
  file="${1:-}"
  xmllike "${file}" get_toolbars_and_actions
}
