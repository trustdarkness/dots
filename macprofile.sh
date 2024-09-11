#!/usr/bin/env bash

# these get rid of the annoying bubbles and update nags in systemprefs if you are
# version locked because you do real work with your computer like some of us
alias killupdates='defaults write com.apple.systempreferences DidShowPrefBundleIDs "com.apple.preferences.softwareupdate"'
alias killbubbles="defaults write com.apple.systempreferences AttentionPrefBundleIDs 0 && killall Dock"

# sometimes these defaults reads can be non-instant
if [ -z $bubbleskilled ]; then
  se "checking for update and icloud warnings to clear..."
  if gt $(defaults read com.apple.systempreferences AttentionPrefBundleIDs) 0; then
    killupdates
    killbubbles
    export bubbleskilled=1
  fi
fi


# disables mouse acceleration which does not seem to play well with 
# synergy or nomachine (maybe both, not sure)
if [ -z $accelkilled ]; then
  alias killaccel="defaults write -g com.apple.mouse.scaling -integer -1"
  if ! lt $(defaults read -g com.apple.mouse.scaling) 0; then
    killaccel
    export accelkilled=1
  fi
fi

if [ -z "${APPFOLDERS[*]}" ]; then
  se "Initializing app folder cache, please hold..." 
  cache_init_application_folders
fi

defaults write com.apple.loginwindow LoginwindowLaunchesRelaunchApps -bool false
  