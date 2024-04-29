#!env bash
echo "Runing bash version $(bash_version)"
eval "$(ssh-agent -s)"

# Setting PATH for Python 3.12
# The original version is saved in .bash_profile.pysave
PATH="$HOME/.local/bin:/Library/Frameworks/Python.framework/Versions/3.12/bin:${PATH}"
export PATH

alias killbubbles="defaults write com.apple.systempreferences AttentionPrefBundleIDs 0 && killall Dock"
alias killupdates='defaults write com.apple.systempreferences DidShowPrefBundleIDs "com.apple.preferences.softwareupdate"'
alias killaccel="defaults write -g com.apple.mouse.scaling -integer -1"
alias du0="du -h -d 0"
alias du1="du -h -d 1"

function sudo-only-commands  {
  # cache sudo password
  sudo ls
  # for a set of .command files, run only the
  # lines starting with sudo
  files=$(ls *.command)
  IFS=$'\n'
  for f in $files; do
    lines=$(cat "$f" |grep sudo|cut -c 5-)
    echo $lines
  done
  confirm_yes "OK to run?"
  for f in $files; do
    lines=$(cat "$f" |grep sudo|cut -c 5-)
    for line in $lines; do
      sudo -i -u root bash -c "$line"
    done
  done
}

function showHidden {
  isShown=$(defaults read com.apple.finder AppleShowAllFiles)
  if [[ $isShown == "false" ]]; then
    defaults write com.apple.finder AppleShowAllFiles true
    killall Finder
  fi
}
showHidden

export OLDSYS="/Volumes/federation"
export OLDHOME="/Volumes/federation/Users/$(whoami)"
function b() {
  source $D/localback.sh
}