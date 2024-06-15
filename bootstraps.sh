# since by definition, we won't have arrays yet, this is a hacky prototype
# we'll use bell separated strings, MACBASHUPS for the prompt strings
# and MACBASHUPA for the actions
MACBASHUPS="Continue, accepting possible breakage\a" 
MACBASHUPS+="Install homebrew and latest bash stable, making this your default shell\a" 
MACBASHUPS+="Install homebrew and latest bash stable, but don't change my shell\a"
MACBASHUPS+="Abort and exit"

MACBASHUPA="return 0\a" 
MACBASHUPA+="bootstrap_modern_bash -s -d -p\a" 
MACBASHUPA+="bootstrap_modern_bash -s -p\a"
MACBASHUPA+="Abort and exit"

local_namerefs="MACBASHUPS\a"
local_namerefs+="MACBASHUPA\a"
local_namerefs+="choices_legacy\a"
local_namerefs+="brew_bootstrap\a"
local_namerefs+="MODERN_BASH\a"
local_namerefs+="brew_get_newest_stable_bash\a"
local_namerefs+="bootstrap_modern_bash\a"
local_namerefs+="cleanup_macbootstraps\a"
local_namerefs+="namerefs"

if ! exists "get_keypress"; then 
  function get_keypress() {
    >/dev/tty printf '%s' "${1:-}"
    [[ $BASH_VERSION ]] && </dev/tty read -rn1
    echo "${REPLY,,}" 
    return 0
  }
  export -f get_keypress
  local_namerefs+="get_keypress"
fi

function choices_legacy() {
  local prompts="${1:-}"
  local actions="${2:-}"
  local pctr=0
  local IFS=$'\a'
  for prompt in "$prompts"; do 
      ((pctr++))
      echo "$ctr. $prompt"
  done
  local chosen=$(get_keypress "Enter choice 1.. ${ctr}: ")
  local actr=0
  local IFS=$'\a'
  for action in "$actions"; do 
    ((actr++))
    if [ $actr == $pctr ]; then
      eval "$action"
    fi
  done
  return $((chosen-1))
}

# Installs brew using their command from the homepage
function brew_bootstrap() {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  brew install jq
  brew_update_cache
}

# Asks formulae.brew.sh (in the case brew isnt installed yet) for its current'
# newest stable version of bash, echos to console no explicit return
function brew_get_newest_stable_bash() {
  # current_cache=$(most_recent_in_dir $BREW_SEARCH)
  # version=$(cat $current_cache|jq 'map(select(.name == "bash")|
  # .versions|.stable)|.[]')
  curl https://formulae.brew.sh/formula/bash --output /tmp/brewbash.html 2> /dev/null
  local localtds=$(xmllint --html --oldxml10 --recover --xpath '//td/text()' \
    2> /dev/null <(cat /tmp/brewbash.html))
  local version=$(awk -F'✅' '{print$3}' <<< "$localtds"|awk -F'⚡' '{print$1}')
  echo $version
}

# definition of modern bash to at least include associative arrays
# and pass by reference
MODERN_BASH="4.3"

# Installs bash from brew, installing brew if it doesn't exist, 
# on success, adds /usr/local/bin/bash to /etc/shells and runs
# chsh -s /usr/local/bin/bash.  Also searches ${BASH_PARENT_SOURCED}
# for PATH= assignments and offers to prepend with /usr/local/bin, 
# basically all the things you need to fix the MacOS default brokenass
# bash. If bash >= 4.3, does nothing (see bootstrap_newest_stable_bash)
# no args, returns > 0 if any step fails along the way
function bootstrap_modern_bash() {
  help() {
    echo << EOF
    Installs a modern version of bash on a MacOS system, also installing
    homebrew along the way, if not already installed.
   
    If bash in the system PATH is >= MODERN_BASH (defaults to 4.3), this
    function returns 0, doing nothing. 

    Args:
      -v | --bash_version	if specified, we will try to forward to 
                                brew to install a specific version. we 
				default to bash stable in brew.
      -s | --etc_shells		if set, we add the newly installed bash
				to /etc/shells.
      -d | --default 		if set, we make the installed bash the 
				default shell for the current user.
      -p | --update_path	if set, we prepend the current PATH with
				/usr/local/bin in any assignments in 
				\$HOME/.bash_profile, \$HOME/.profile
				or \$HOME/.bashrc

    -h | -? | --help 		Prints this text.  

    returns 0 if all actions succeeded.
EOF
  }
  local default_shell=false
  local etc_shells=false
  local update_path=false
  local version
  while [ $# -gt 0 ]; do
    case "${1:-}" in
      "-v"|"--bash_version")
        version="${2:$MODERN_BASH}"
        shift
        shift
        ;;
      "-d"|"--default")
        default_shell=true
        shift
        ;;
      "-h"|"-?"|"--help")
        help
        shift
        ;;
      "-s"|"--etc_shells")
        etc_shells=true
        shift
        ;;
      "-p"|"--update_path")
        update_path=true
        shift
        ;;
       *)
        help
        ;;
    esac
  done
  version="${1:-${MODERN_BASH}}"
  local major=$(awk -F'.' '{print$1}')
  local minor=$(awk -F'.' '{print$2}')
  local out
  if out=$(declare -pF bash_version); then 
    if [ bash_version -ge "$version" ]; then 
      return 0
    fi
  # since we're bootstrapping bash, lets not take anything for granted
  elif [ ${BASH_VERSION_INFO[0]} -gt $((major-1)) ] && \
    [ ${BASH_VERSION_INFO[1]} -gt $((minor-1)) ]; then
    return 0
  fi
  local brew=$(type -p brew)
  if [ $? -gt 0 ]; then
    brew_bootstrap
  fi
  if [[ ${version} != ${MODERN_BASH} ]]; then  
    local newest_stable=$(brew_get_newest_stable_bash)
    if [[ ${version} == ${newest_stable} ]]; then
      brew install bash
    elif [[ ${version} > ${newest_stable} ]]; then
      echo "newest stable bash in brew is ${newest_stable}"
      if confirm_yes "Would you like to install HEAD?"; then 
        brew install bash@HEAD
      else 
        return 1
      fi
    else
      brew install bash@${version}
    fi
  fi
  if ! $(brew list bash > /dev/null); then
    brew install bash
  fi
  if $etc_shells; then 
    sudo sh -c 'echo /usr/local/bin/bash >> /etc/shells'
  fi
  if $default_shell; then 
    chsh -s /usr/local/bin/bash
  fi
  if $update_path; then 
    path_sources='.bashrc\a.bash_profile\a.profile'
    local failed=0
    local IFS='\a'
    for sourced in "$path_sources"; do
      if ! [ -f "$sourced" ]; then 
        se "Couldn't find $sourced. Skipping."
        continue
      fi 
      local grepout=$(grep "PATH=" "$sourced")
      local brewbash=$(grep "\/usr\/local\/bin" <<< "$grepout")
      if [ $? -gt 0 ]; then 
        if confirm_yes "prepend /usr/local/bin to PATH in $sourced?"; then
          if ! sed -i 's:PATH=:PATH=/usr/local/bin:g' "$sourced"; then 
            ((failed++))
          fi
        fi
      fi
    done
  fi
}

function bash_bootstrap() {
  bootstrap_modern_bash -s -d -p
}

function completion_bootstrap() {
  if [[ $(uname) == 'Darwin' ]]; then
    bc2=$(brew list bash-completion@2)
    if [ $? -gt 0 ]; then
      >&2 printf "Modern bash and brew installed completion (@2) recommended\n"
      >&2 printf "otherwise, ymmv\n\n"
      >&2 printf "brew install bash\n"
      >&2 printf "brew install bash-completion@2\n"
    fi
  fi
  # enable programmable completion features (you don't need to enable
  # this, if it's already enabled in /etc/bash.bashrc and /etc/profile
  # sources /etc/bash.bashrc).
  if ! shopt -oq posix; then
    if ! type -p _init_completion > /dev/null; then
      if [ -f /etc/profile.d/bash_completion.sh ]; then
        source /etc/profile.d/bash_completion.sh
      elif [[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]]; then
         source "/usr/local/etc/profile.d/bash_completion.sh"
      elif [ -f /usr/local/etc/bash_completion ]; then
        source /usr/local/etc/bash_completion
      elif [ -d /usr/local/etc/bash_completion.d ]; then
        for file in $(ls /usr/local/etc/bash_completion.d); do
          if [ -e "${file}" ]; then
            source "${file}"
          fi
        done
      elif [ -f /usr/share/bash-completion/bash_completion ]; then
        source /usr/share/bash-completion/bash_completion
      elif [ -f /etc/bash_completion ]; then
        source /etc/bash_completion
      fi
    fi
  fi
  # double check and print an error if we didn't succeed
  if ! type -p _init_completion; then
    >&2 printf "_init_completion not available, we may have failed to setup\n"
    >&2 printf "bash completion."
  fi
}

function mac_bootstrap() {
  # https://apple.stackexchange.com/questions/195244/concise-compact-list-of-all-defaults-currently-configured-and-their-values
  echo "Hostname: "
  read COMPUTER_NAME
  sudo scutil --set ComputerName $COMPUTER_NAME
  sudo scutil --set HostName $COMPUTER_NAME
  sudo scutil --set LocalHostName $COMPUTER_NAME
  sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string $COMPUTER_NAME
  bash_bootstrap
  brew install transmit sshfs iterm2
  brew cask sublime-text sublime-merge
  powerline_bootstrap
  term_bootstrap
  # disable springloaded folders
  defaults write NSGlobalDomain com.apple.springing.enabled 0
  # setup completion for bash, etc
  completion_bootstrap
  # hide the spotlight icon
  sudo chmod 600 /System/Library/CoreServices/Search.bundle/Contents/MacOS/Search
  # xpand the save panel by default
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
  # quit printer app once the print jobs complete
  defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true
  # Reveal IP address, hostname, OS version, etc. when clicking the clock in the login window"
  sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
  # disable smartquotes and smart dashes
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  # Increas sound quality for Bluetooth headphones/headsets
  defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40
  # show hidden files
  defaults write com.apple.Finder AppleShowAllFiles -bool true
  defaults write com.apple.finder AppleShowAllFiles TRUE
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  # show status bar and use posix path as window title
  defaults write com.apple.finder ShowStatusBar -bool true
  defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  # disable disk image verify
  defaults write com.apple.frameworks.diskimages skip-verify -bool true
  defaults write com.apple.frameworks.diskimages skip-verify-locked -bool true
  defaults write com.apple.frameworks.diskimages skip-verify-remote -bool true
  # remove default dock icons
  defaults write com.apple.dock persistent-apps -array
  # Enabling UTF-8 ONLY in Terminal.app and setting the Pro theme by default
  defaults write com.apple.terminal StringEncodings -array 4
  defaults write com.apple.Terminal "Default Window Settings" -string "Pro"
  defaults write com.apple.Terminal "Startup Window Settings" -string "Pro"
  xcode-select --install
}

function yabridge_bootstrap() {
  if [ -d $HOME/Downloads/yabridge ]; then 
    cp -r $HOME/Downloads/yabridge $HOME/.local/share/
  elif [ -d $HOME/bin/yabridge ]; then 
    cp -r $HOME/bin/yabridge $HOME/.local/share/
  else
    >&2 printf "Can't find yabridge updates in"
    >&2 printf "$HOME/Downloads or $HOME/bin"
  fi
}

function rcdefaultapp_bootstrap() {
  mkdir -p "$HOME/Downloads/staging"
  cd "$HOME/Downloads/staging"
  wget https://www.rubicode.com/Downloads/RCDefaultApp-2.1.X.dmg


# breadcrumbs... for (relatively?) tearfree cross platform setup:
function powerline_bootstrap() {
  if ! type pipx >/dev/null 2>&1; then
    if ! [ -n "${p3}" ]; then
      if ! p3=$(type -p python3); then
        echo "python3 doesn't seem to be in \$PATH..."
        # TODO: finish
      fi
    fi
    pipx install powerline-status
    mkdir -p .local/share/powerline
		if [ -z "${psh}" ]; then
      if ! psh=$(find $(pipx list |head -n1 |awk '{print$NF}') -name "powerline.sh" 2> /dev/null |grep "bash"); then
			  se "can't find powerline.sh, assign psh= and run again"
        return 1
			fi
		fi

    ln -is "${psh}"	$HOME/.local/share/powerline/
  else
    >&2 printf "Would be less painful with pipx."
    >&2 printf "  on debian based systems, try sudo apt install pipx"
    >&2 printf "  on mac, install homebrew, then brew cask python; brew cask pipx"
    >&2 printf "Or something, you know the deal."
  fi
}

# my basic edits to import-schemes.sh below will detect and add color
# schemes for xfce4-terminal and konsole.  At the bare minimum, I plan
# to add terminator in addition to iTerm which is what the script
# was originally written for, so this function remains generally OS 
# agnostic.
function termschemes_bootstrap() {
  if ! [ -d "$GH/Terminal-Color-Schemes" ]; then 
    ghc "git@github.com:trustdarkness/Terminal-Color-Schemes.git"
  fi
  cd "$GH/Terminal-Color-Schemes"
  tools/import-schemes.sh
  cd -
}

# in the spirit of consistency, we'll keep these together
function termfonts_bootstrap() { 
  if ! $(fc-list |grep Hack-Regular); then 
    if [[ uname == "Darwin" ]]; then 
      brew install font-hack
    elif [[ uname == "Linux" ]]; then
      if ! $(i); then  
        se "no installutil.sh" 
        return 1 
      fi 
      if ! $(sai fonts-hack); then  
        se "could not install fontshack with ${sai}"
        return 1
      fi
    fi
  fi
  return 0
}

function term_bootstrap() {
  termschemes_bootstrap
  termfonts_bootstrap
}

function mullvad_bootstrap() {
  if [[ uname == "Darwin" ]]; then
    if ! type -p brew > /dev/null 2>&1; then
      se "please make sure brew_bootstrap has run."
      return 1
    fi
    brew install gpg
    brew install wget
    mkdir -p $HOME/Downloads/staging
    cd $HOME/Downloads/staging
    wget https://mullvad.net/en/download/app/pkg/latest
    wget https://mullvad.net/en/download/app/pkg/latest/signature
    wget https://mullvad.net/media/mullvad-code-signing.asc
    gpg --import mullvad-code-signing.asc
    verify=gpg --verify Mullvad*.asc
    if [ $? -ne 0 ]; then 
      se "Mullvad gpg verification failed."
      return 1
    fi
    if ! sudo installer -pkg Mullvad*.pkg -target /; then 
      se "installer failed with code $?"
    else 
      return 0
    fi
  elif [[ uname == "linux" ]]; then 
    distro="$(lsb_release -d 2>&1|grep Desc|awk -F':' '{print$2}'|xargs)"
    if string_contains "(fedora|nobara)" "$distro"; then
      # Add the Mullvad repository server to dnf
      sudo dnf config-manager --add-repo https://repository.mullvad.net/rpm/stable/mullvad.repo

      # Install the package
      if sudo dnf install mullvad-vpn; then
        return 0
      fi
    elif string_contains "(Debian|Ubuntu)" "$distro"; then
      # Download the Mullvad signing key
      sudo curl -fsSLo /usr/share/keyrings/mullvad-keyring.asc https://repository.mullvad.net/deb/mullvad-keyring.asc

      # Add the Mullvad repository server to apt
      echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=$( dpkg --print-architecture )] https://repository.mullvad.net/deb/stable $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/mullvad.list

      # Install the package
      sudo apt update
      if sudo apt install mullvad-vpn; then 
        return 0
      fi 
    else 
      se "couldn't parse distro from $distro, or we don't have setup"
      se "code that is distro specific.  exiting."
      return 1
    fi
  fi
}


function disarm_bootstrap() {
  if ! disarm=$(type -p disarm); then 
    mkdir -p "$HOME/downloads/_installed_foundation/disarm"
    cd "$HOME/downloads/_installed_foundation/disarm"
    curl https://newosxbook.com/tools/disarm.tar --output disarm.tar
    tar xf disarm.tar
    if [[ $(system_arch) == "x86_64" ]]; then 
      cp binaries/disarm.x86 $HOME/.local/bin/
      ln -sf $HOME/.local/bin/disarm.x86 $HOME/.local/bin/disarm
      mkdir -p $HOME/.local/share/multiarch
      cp binaries/* $HOME/.local/share/multiarch/
      path_append "$HOME/.local/share/multiarch/"
    fi
  fi
}

function mnlooto_bootstrap() {
  if ! mn=$(type -p mn); then 
    if ! mnsh=$(type -p mn.sh); then
      # assume nothing is installed
      ghc https://github.com/krypted/looto.git
      if ! [[ $(basename $(pwd)) == "looto" ]]; then 
        cd "$HOME/src/github/looto"
      fi
      cp looto.sh "$HOME/.local/bin/"
      cp mn.sh "$HOME/.local/bin/"
      ln -sf "$HOME/.local/bin/looto.sh" "$HOME/.local/bin/looto"
      ln -sf "$HOME/.local/bin/mn.sh" "$HOME/.local/bin/mn"
    fi
  fi
}

# TODO: poopulate updated namerefs and use cleanup function in util
function cleanup_macbootstraps() {
  local IFS=$'\a'
  for nameref in "$local_namerefs"; do
    unset $nameref
  done
}
