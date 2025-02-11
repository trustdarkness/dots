#!/usr/bin/env bash
#
#QT_STYLE_OVERRIDE=
#QT_QPA_PLATFORMTHEME=qt5ct
#export QT_STYLE_OVERRIDE=gtkexport
load-function -q untru
if untru "$KDE_FULL_SESSION"; then
  export QT_QPA_PLATFORMTHEME=qt5ct
else
  export QT_QPA_PLATFORMTHEME=kde
  QT_QUICK_CONTROLS_STYLE=org.kde.desktop
fi

kde_theme_paths=(
  "$HOME/.local/share/aurorae/themes/"
  "$HOME/.local/share/plasma/look-and-feel"
  "$HOME/.local/share/plasma/desktoptheme"
  "$HOME/.themes"
  "$HOME/.local/share/icons"
  "/usr/share/sddm/themes/"
  "/usr/lib/qt/plugins/styles" # so files for qt5
  "/usr/lib/qt6/plugins/styles" # so files for qt6
  "/usr/lib/qt6/plugins/org.kde.kdecoration2/"
  "/usr/share/kstyle/themes/"
)

function qdbus_detect_and_install() {
  if ! type -p qdbus-qt5 2>&1 > /dev/null; then
    if ! is_function qdbus_bootstrap; then
      source "$D/bootstraps.sh" && sourced+=("$D/bootstraps.sh")
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

sddm-theme-plasma6-compatible() {
  optspec="dvichtw"
  disable_incompatible=false
  verbose=false
  quiet=false
  show_compatible=true
  show_incompatible=true
  printftemplate="%s\n"
  test=false
  compatible= ; unset compatible; compatible=()
  incompatible= ; unset incompatible; incompatible=()
  confirmred_incompatible= ; unset confirmed_incompatible; confirmed_incompatible=()
  pager="cat"
  ts=$(fsts)
  unset OPTIND
  unset optchar
  while getopts "${optspec}" optchar; do
    case "${optchar}" in
      d)
        disable=true
        disabled=/usr/share/sddm/themes_disabled
        ;;
      v)
        verbose=true
        ;;
      i)
        show_compatible=false
        ;;
      c)
        show_incompatible=false
        ;;
      q)
        quiet=true
        ;;
      t)
        test=true
        ;;
      w)
        pager="column"
        ;;
    esac
  done
  failures=0
  if ! $show_compatible && ! $show_incompaitble && $quiet; then
    err "-q only makes sense with exactly one of -i or -c"
    usage
    return 1
  fi
  if ! $quiet; then
    # to indent under the heading of compat/incompat"
    printftemplate="  %s\n"
  fi
  i=0
  for themedir in "/usr/share/sddm/themes/"*; do
    themename="$(basename "$themedir")"
    importstr="$(grep -id skip components "${themedir}/"* 2>&1)"
    if $test; then
      if [ -d "$CACHE" ]; then
        cachedir="$CACHE/$FUNCNAME/$ts"
        mkdir -p "$cachedir"
        confirmed_incompatible="$cachedir/confirmed_incompatible"
        set -m
        {
          while IFS= read -r -d $'\n' line; do
            if grep "Fallback" < <(echo "$line")  > /dev/null 2>&1; then
              if ! grep "$themename" "$confirmed_incompatible"  > /dev/null 2>&1; then
                echo "$themename" >> "$confirmed_incompatible"
              fi
            fi
          done < <(sddm-greeter-qt6 --test-mode --theme "$themedir" 2>&1)
        } &
        child=$! > /dev/null 2>&1
        ( sleep 0.5 && kill -- -$child > /dev/null 2>&1 ) &
        wait $child  > /dev/null 2>&1
      else
        echo "CACHE not setup properly, skipping -t testing"
      fi
    fi

    if [[ "$importstr" == *3\.0* ]]; then
      compatible+=("$themename")
      # se "$themename appears to be Plasma 6 compatible."
      continue
    else
      incompatible+=("$themename")
      # se "$themename appears to be incompatible with Plasma 6."
      # if $verbose; then
      #   se "  per %s " "$importstr"
      # sddm-greeter-qt6 --test-mode --theme "$themedir" 2>&1 |
      #  { grep "Fallback" && kill $!; }
      # se "confirmed in test mode"
      # fi
      ((failures++))
    fi
    ((i++))
    # if [ $i -gt 2 ]; then
    #   break
    # fi
  done

  if [ "${#compatible[@]}" -gt 0 ]; then
    if ! $quiet; then
      echo "Plasma 6 Compatible SDDM Themes:";
    fi
    {  for theme in "${compatible[@]}"; do
         printf "$printftemplate" "$theme"
       done
    } | $pager
  fi
  if [ -s "$confirmed_incompatible" ]; then
    if ! $quiet; then
      echo "These themes failed sddm-greeter --test-mode:"
    fi
    {  while IFS=$'\n' read -r -d $'\n' theme; do
        printf "$printftemplate" "$theme"
      done < "$confirmed_incompatible"
    } | $pager
  fi
  if [ "${#incompatible[@]}" -gt 0 ]; then
    if ! $quiet; then
      echo "These themes may have compatibility issues with Plasma 6, but seem to display:"
    fi
    {  for theme in "${incompatible[@]}"; do
        if ! grep "$theme" "$confirmed_incompatible" > /dev/null 2>&1; then
          printf "$printftemplate" "$theme"
        fi
      done
    } | $pager
  fi
  if $disable; then
    failures=0
    echo "disabling themes that failed test-mode"
    if confirm_yes; then
      disabled_parent="$(dirname "$disabled")"
      # if can_i_write "$disabled_parent"; then
      #   mkdir -p "$disabled"
      #   for theme in "${confirmed_incompatible[@]}"; do
      #     if ! mv "$theme" "$disabled"; then
      #       err "mv $theme $disabled failed with code $?"
      #       ((failures++))
      #     fi
      #   done
      # else
        sudo mkdir -p "$disabled"
        while IFS=$'\n' read -r -d $'\n' theme; do
          if ! sudo mv "/usr/share/sddm/themes/$theme" "$disabled"; then
            err "sudo mv $theme $disabled failed with code $?"
            ((failures++))
          fi
        done < "$confirmed_incompatible"
      # fi
    fi
  fi
  return $failures
}