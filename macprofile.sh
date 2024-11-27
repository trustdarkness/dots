#!/usr/bin/env bash

# these get rid of the annoying bubbles and update nags in systemprefs if you are
# version locked because you do real work with your computer like some of us
alias killupdates='defaults write com.apple.systempreferences DidShowPrefBundleIDs "com.apple.preferences.softwareupdate"'
alias killbubbles="defaults write com.apple.systempreferences AttentionPrefBundleIDs 0 && killall Dock"

# sometimes these defaults reads can be non-instant
bubbleskilled=$(launchctl getenv bubbleskilled)
if [ -z "$bubbleskilled" ]; then
  se "checking for update and icloud warnings to clear..."
  if gt "$(defaults read com.apple.systempreferences AttentionPrefBundleIDs)" 0; then
    killupdates
    killbubbles
    launchctl setenv bubbleskilled true
  fi
fi

relaunch=$(defaults read com.apple.loginwindow LoginwindowLaunchesRelaunchApps)
if [ -n "$relaunch" ] && [ "$relaunch" -ne 0 ]; then
  defaults write com.apple.loginwindow LoginwindowLaunchesRelaunchApps -bool false
fi
  
launchctl setenv MACPROFILED true