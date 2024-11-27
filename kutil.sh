#!/usr/bin/env bash
#
#QT_STYLE_OVERRIDE=
#QT_QPA_PLATFORMTHEME=qt5ct

function klogout() {
  shutdown_confirm=0 # 0 no, 1 yes, -1 default
  shutdown_type=0 # 0 logout, 1 reboot, 2 halt, 3 logout, -1 default
  shutdown_mode=2 # 0 schedule, 1 try now, 2 force now, 3 interactive, -1 default
  qdbus-qt5 org.kde.ksmserver /KSMServer logout $shutdown_confirm $shutdown_type $shutdown_mode

}

alias konsession="qdbus $KONSOLE_DBUS_SERVICE $KONSOLE_DBUS_SESSION"
alias konwindow="qdbus $KONSOLE_DBUS_SERVICE $KONSOLE_DBUS_WINDOW"
alias kontd="konsession setProfile td"

function konsole_bootstrap() {
  term_bootstrap
  local profile="$HOME/.local/share/konsole/td.profile"
  if ! [ -f "${profile}" ]; then 
    cat <<EOF > "${profile}"
[Appearance]
ColorScheme=Afterglow
Font=Hack,10,-1,5,50,0,0,0,0,0
UseFontLineChararacters=true

[General]
Name=td
Parent=FALLBACK/
TerminalColumns=80
TerminalRows=50

[Interaction Options]
CopyTextAsHTML=false
TrimLeadingSpacesInSelectedText=true

[Scrolling]
HistoryMode=2
EOF
  fi
  kontd
}

alias skprofile="konsession setProfile td"
alias vkprofile="vim .local/share/konsole/td.profile && skprofile"

function list_kwin_commands() {
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
