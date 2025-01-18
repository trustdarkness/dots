#!/usr/bin/env bash
launchctl setenv MACPROFILED TRUE
launchctl setenv POWERLINE TRUE

# these get rid of the annoying bubbles and update nags in systemprefs if you are
# version locked because you do real work with your computer like some of us
alias killupdates='defaults write com.apple.systempreferences DidShowPrefBundleIDs "com.apple.preferences.softwareupdate"'
alias killbubbles="defaults write com.apple.systempreferences AttentionPrefBundleIDs 0 && killall Dock"

# sometimes these defaults reads can be non-instant
bubblecheck=$(launchctl getenv bubblecheck)
if [ -z "$bubblecheck" ]; then
  launchctl setenv bubbleskilled TRUE
  se "[runonce / session] checking for update and icloud warnings to clear..."
  if gt "$(defaults read com.apple.systempreferences AttentionPrefBundleIDs)" 0; then
    killupdates
    killbubbles
  fi
fi

ds_store_network=$(defaults read com.apple.desktopservices DSDontWriteNetworkStores)
if [ -z "$ds_store_network" ] || [ "$ds_store_network" -ne 1 ]; then
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool TRUE
fi
relaunch=$(defaults read com.apple.loginwindow LoginwindowLaunchesRelaunchApps)
if [ -z "$relaunch" ] || [ "$relaunch" -ne 0 ]; then
  defaults write com.apple.loginwindow LoginwindowLaunchesRelaunchApps -bool FALSE
fi
