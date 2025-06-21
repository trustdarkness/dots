#!/usr/bin/env bash
launchctl setenv MACPROFILED TRUE
launchctl setenv POWERLINE FALSE

# Sets up homebrew, updating PATH and other relavent bits for arm64 or intel
function brew_detect_arch() {
  # https://joel-azemar.medium.com/migrate-brew-formulas-from-intel-to-arm-on-m1-982764628b02
  local arm_homebrew_prefix="/opt/homebrew"
  local intel_homebrew_prefix="/usr/local"
  case "$(uname -m)" in
    "arm64")
      homebrew_prefix=${arm_homebrew_prefix}
      # echo "Start Home Brew as ARM64 M1 Sillicon ✅"
    ;;
    "i386"|"x86-64")
      homebrew_prefix=${intel_homebrew_prefix}
      # echo "Start Home Brew under Rosetta 2 Intel Emulation x86_64 🤔"
    ;;
    *)
      echo "Which Processor Architecture is that? [$(uname -m)]"
    ;;
  esac
  # $ brew help shellenv
  # ...
  # Print export statements. When run in a shell, this installation of Homebrew will
  # be added to your PATH, MANPATH, and INFOPATH.

  # The variables $HOMEBREW_PREFIX, $HOMEBREW_CELLAR and $HOMEBREW_REPOSITORY
  # are also exported to avoid querying them multiple times...
  eval "$($homebrew_prefix/bin/brew shellenv)"
}
brew_detect_arch

# definition of modern bash to at least include associative arrays
# and pass by reference
MODERN_BASH="4.3"

if version_lt "$BASH_VERSION" "$MODERN_BASH"; then
  # because we just ran brew_detect arch, we should have modern bash in PATH
  bash
fi

# these get rid of the annoying bubbles and update nags in systemprefs if you are
# version locked because you do real work with your computer like some of us. (Monterey and before)
# alias killupdates='defaults write com.apple.systempreferences DidShowPrefBundleIDs "com.apple.preferences.softwareupdate"'
# alias killbubbles="defaults write com.apple.systempreferences AttentionPrefBundleIDs 0 && killall Dock"

# sometimes these defaults reads can be non-instant (Monterey and before)
# bubblecheck=$(launchctl getenv bubblecheck)
# if [ -z "$bubblecheck" ]; then
#   launchctl setenv bubbleskilled TRUE
#   se "[runonce / session] checking for update and icloud warnings to clear..."
#   if gt "$(defaults read com.apple.systempreferences AttentionPrefBundleIDs)" 0; then
#     killupdates
#     killbubbles
#   fi
# fi

ds_store_network=$(defaults read com.apple.desktopservices DSDontWriteNetworkStores)
if [ -z "$ds_store_network" ] || [ "$ds_store_network" -ne 1 ]; then
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool TRUE
fi
relaunch=$(defaults read com.apple.loginwindow LoginwindowLaunchesRelaunchApps)
if [ -z "$relaunch" ] || [ "$relaunch" -ne 0 ]; then
  defaults write com.apple.loginwindow LoginwindowLaunchesRelaunchApps -bool FALSE
fi
