# since by definition, we wont have arrays yet, this is a hacky prototype
# we'll use bell separated strings, MACBASHUPS for the prompt strings
# and MACBASHUPA for the actions
MACBASHUPS="Continue, accepting possible breakage\a" 
MACBASHUPS+="Install homebrew and latest bash stable, making this your default shell\a" 
MACBASHUPS+="Install homebrew and latest bash stable, but dont change my shell\a"
MACBASHUPS+="Abort and exit"

MACBASHUPA="
local caller="$FUNCNAME"
mb_ff "$FUNCNAME"; return 0\a" 
MACBASHUPA+="bootstrap_modern_bash -s -d -p\a" 
MACBASHUPA+="bootstrap_modern_bash -s -p\a"
MACBASHUPA+="Abort and exit"

BREW_BATCH_INSTALLS="python3 sshfs iterm2 raycast wget rar 7-zip gpg pipx"
BREW_BATCH_CASKS="transmit sublime-text sublime-merge lynx"

PATH_SOURCEES='.bashrc .bash_profile .profile'

INSTALL_STAGING="$HOME/Downloads/Staging"
INSTALL_LOGS="$HOME/Downloads/_i_logs"
INSTALLED_SUCCESSFULLY="$HOME/Downloads/_i"

local_namerefs="MACBASHUPS\a"
local_namerefs+="MACBASHUPA\a"
local_namerefs+="choices_legacy\a"
local_namerefs+="brew_bootstrap\a"
local_namerefs+="MODERN_BASH\a"
local_namerefs+="brew_get_newest_stable_bash\a"
local_namerefs+="bootstrap_modern_bash\a"
local_namerefs+="cleanup_macbootstraps\a"
local_namerefs+="namerefs"

shopt -s expand_aliases

if ! exists "get_keypress"; then 
  if [ -n "$D" ]; then 
    source "$D/user_prompts.sh"
  else
    >&2 printf "env not as expected"
  fi
fi

function tokenizer() {
  separator=' '
  if [ "$1" = '-F' ]; then 
    separator="$2"
    shift; shift;
  fi
  input="$@"
  ( 
    set -f -- 
    local IFS=$separator
    while read -r token ; do 
      set -- "$@" $token 
    done < <(echo "$input")
    printf %s "$*" 
  )
}

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
  if ! timed_confirm_yes "Continue with $FUNCNAME?"; then
 local caller="$FUNCNAME"
 mb_ff "$FUNCNAME"; return 0; fi
  if type -p brew; then 
    echo "already bootstrapped; return to the 0"

    local caller="$FUNCNAME"
    mb_ff "$FUNCNAME"; return 0
  fi
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  brew install jq
  brew_update_cache

  local caller="$FUNCNAME"
  mb_ff "$FUNCNAME"; return 0
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
  local version=$(echo "$localtds"| awk -F'✅' '{print$3}'|awk -F'⚡' '{print$1}')
  echo $version
}

# definition of modern bash to at least include associative arrays
# and pass by reference
MODERN_BASH="4.3"

# Installs bash from brew, installing brew if it doesnt exist, 
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
        version="${2:-$MODERN_BASH}"
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
  local major=$(echo $version |awk -F'.' '{print$1}')
  local minor=$(echo $version |awk -F'.' '{print$2}')
  local out
  local bmajor=$(echo $BASH_VERSION|awk -F'.' '{print$1}')
  local bminor=$(echo $BASH_VERSION|awk -F'.' '{print$1}')
  # since we're bootstrapping bash, lets not take anything for granted
  if [ $bmajor -gt $((major-1)) ] && \
    [ $bminor -gt $((minor-1)) ]; then

    local caller="$FUNCNAME"
    mb_ff "$FUNCNAME"; return 0
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
    : #sudo sh -c 'echo /usr/local/bin/bash >> /etc/shells'
  fi
  if $default_shell; then 
    : #chsh -s /usr/local/bin/bash
  fi
  if $update_path; then 
    local failed=0
    for sourced in $(tokenize "$PATH_SOURCES"); do
      if ! [ -f "$sourced" ]; then 
        se "Couldnt find $sourced. Skipping."
        continue
      fi 
      local grepout=$(grep "PATH=" "$sourced")
      local brewbash=$(echo "$grepout" |grep "\/usr\/local\/bin")
      if [ $? -gt 0 ]; then 
        if confirm_yes "prepend /usr/local/bin to PATH in $sourced?"; then
          if ! sed -i 's:PATH=:PATH=/usr/local/bin:g' "$sourced"; then 
            ((failed++))
          fi
        fi
      fi
    done
  fi
  if [ -n "$failed" ]; then
    if [ $failed -eq 0 ]; then 

      local caller="$FUNCNAME"
      mb_ff "$FUNCNAME"; return 0
    else 
      return $failed
    fi
  fi

  local caller="$FUNCNAME"
  mb_ff "$FUNCNAME"; return 0
}

function bash_bootstrap() {
  if ! timed_confirm_yes "Continue with $FUNCNAME?"; then
 local caller="$FUNCNAME"
 mb_ff "$FUNCNAME"; return 0; fi
  bootstrap_modern_bash -s -d -p

  local caller="$FUNCNAME"
  mb_ff "$FUNCNAME"; return 0
}

function terminal_hack() {
  defaults write com.apple.Terminal 'Window Settings' -dict-add Basic '<dict><key>Font</key><data>YnBsaXN0MDDUAQIDBAUGBwpYJHZlcnNpb25ZJGFyY2hpdmVyVCR0b3BYJG9iamVjdHMSAAGGoF8QD05TS2V5ZWRBcmNoaXZlctEICVRyb290gAGkCwwVFlUkbnVsbNQNDg8QERITFFZOU1NpemVYTlNmRmxhZ3NWTlNOYW1lViRjbGFzcyNAJgAAAAAAABAQgAKAA1xIYWNrLVJlZ3VsYXLSFxgZGlokY2xhc3NuYW1lWCRjbGFzc2VzVk5TRm9udKIZG1hOU09iamVjdAgRGiQpMjdJTFFTWF5nbnd+hY6QkpShprG6wcQAAAAAAAABAQAAAAAAAAAcAAAAAAAAAAAAAAAAAAAAzQ==</data><key>FontAntialias</key><true /><key>FontWidthSpacing</key><real>1.004032258064516</real><key>ProfileCurrentVersion</key><real>2.07</real><key>name</key><string>Basic</string><key>type</key><string>Window Settings</string></dict>'
}

function completion_bootstrap() {
  if ! timed_confirm_yes "Continue with $FUNCNAME?"; then
 local caller="$FUNCNAME"
 mb_ff "$FUNCNAME"; return 0; fi
  if [[ $(uname) == 'Darwin' ]]; then
    function install_completion() {
      bc2=$(brew install "bash-completion@2")
      if [ $? -gt 0 ]; then
        >&2 printf "Modern bash and brew installed completion (@2) recommended\n"
        >&2 printf "otherwise, ymmv\n\n"
        >&2 printf "brew install bash\n"
        >&2 printf "brew install bash-completion@2\n"
      fi
    }
  fi
  # enable programmable completion features (you dont need to enable
  # this, if it's already enabled in /etc/bash.bashrc and /etc/profile
  # sources /etc/bash.bashrc).
  if ! shopt -oq posix; then
    if ! type -p _init_completion > /dev/null; then
      if [ -f /etc/profile.d/bash_completion.sh ]; then
        source /etc/profile.d/bash_completion.sh
      elif [ -L "/usr/local/etc/profile.d/bash_completion.sh" ]; then
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
  # double check and print an error if we didnt succeed
  if ! type -p _init_completion; then
    if [[ $(uname) == 'Darwin' ]]; then
      install_completion
    fi
    >&2 printf "_init_completion not available, we may have failed to setup\n"
    >&2 printf "bash completion."
    return 1
  else

    local caller="$FUNCNAME"
    mb_ff "$FUNCNAME"; return 0
  fi
}

function mac_bootstrap() {
  # https://apple.stackexchange.com/questions/195244/concise-compact-list-of-all-defaults-currently-configured-and-their-values
  log="$INSTALL_LOGS/mac_bootstrap.log"
  is_completed() {
    gout=$(grep "$1" "$log")
    return $?
  }
  
  report() {
    se "recorded status for the following components:"
    se ""
    cat "$log"
  }
  trap report SIGINT EXIT

  if [ -n "$SET_HOSTNAME" ]; then 
    printf "Hostname for this Mac: "
    read COMPUTER_NAME
    echo "Setting ComputerName to $OMPUTER_NAME"
    sudo scutil --set ComputerName $COMPUTER_NAME
    echo "Setting HostName to $COMPUTER_NAME"
    sudo scutil --set HostName $COMPUTER_NAME
    echo "Setting LocalHostName to $COMPUTER_NAME"
    sudo scutil --set LocalHostName $COMPUTER_NAME
    echo "Setting NetBIOSName to $COMPUTER_NAME"
    sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string $COMPUTER_NAME
    echo 'Is there a domain for DNS? (We dont configure Active Directory)'
    if confirm_yes '(Y/n)'; then 
      printf "Domain for $COMPUTER_NAME to be added to /etc/hosts as $COMPTUER_NAME.domain.tld: "
      read DOMAIN
      if [ -n "$DOMAIN" ]; then 
        echo "127.0.0.1\t$COMPUTER_NAME.$DOMAIN" | sudo tee -a /etc/hosts
      fi
    fi
  set -euo pipefail
  printf "Installing brew"
  brew_bootstrap
  echo " and modern bash"
  bash_bootstrap
  fi
  if ! is_completed "BREW_BATCH_INSTALLS"; then
  echo "Installing $BREW_BATCH_INSTALLS"
  if ! brew install $BREW_BATCH_INSTALLS; then
    se "brew install $BREW_BATCH_INSTALLS failed with $?"
    se "please fix and try again"
    return 1
  fi
fi
  if ! is_completed "BREW_BATCH_CASKS"; then
  echo "Installing casks $BREW_BATCH_CASKS"
  if ! brew install --cask $BREW_BATCH_CASKS; then
    se "exit $?: !! please  fix and try again"
    return 1
  fi
fi
  if ! type -p pipx; then 
    se "no pipx, install and try again"
    return 1
  fi

  echo "Setting up powerline-status"
  powerline_bootstrap
  echo "Setting up fonts and color schemes for iTerm"
  term_bootstrap
  echo "Disabling springloaded folders"
  defaults write NSGlobalDomain com.apple.springing.enabled 0
  echo "Setting up completion for bash, etc"
  completion_bootstrap
  echo "Hiding the spotlight icon"
  sudo chmod 600 /System/Library/CoreServices/Search.bundle/Contents/MacOS/Search
  echo "Expanding the save panel by default"
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
  echo "Setting to quit the printer app once the print jobs complete"
  defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true
  echo "Setting that we should reveal IP address, hostname, OS version, etc. when clicking the clock in the login window"
  sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
  echo "Disabling smartquotes and smart dashes"
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  echo "Setting increased sound quality for Bluetooth headphones/headsets"
  defaults write com.apple.BluetoothAudioAgent 'Apple Bitpool Min (editable)' -int 40
  echo "Setting to show hidden files and file extensions  by default"
  defaults write com.apple.Finder AppleShowAllFiles -bool true
  defaults write com.apple.finder AppleShowAllFiles TRUE
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  echo "Setting that we should show status bar and use posix path as window title"
  defaults write com.apple.finder ShowStatusBar -bool true
  defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  echo "Disabling disk image verify"
  defaults write com.apple.frameworks.diskimages skip-verify -bool true
  defaults write com.apple.frameworks.diskimages skip-verify-locked -bool true
  defaults write com.apple.frameworks.diskimages skip-verify-remote -bool true
  echo "Removing default dock icons"
  defaults write com.apple.dock persistent-apps -array
  echo "Enabling UTF-8 ONLY in Terminal.app and setting the Pro theme by default"
  defaults write com.apple.terminal StringEncodings -array 4
  defaults write com.apple.Terminal "Default Window Settings" -string "Pro"
  defaults write com.apple.Terminal "Startup Window Settings" -string "Pro"
  echo "Setting up mnloto and disarm"
  disarm_bootstrap
  mnloto_bootstrap
  echo "Setting up Xcode"
  xcode-select --install
  echo "Installing mullvad"
  mullvad_bootstrap
  set +e
  echo "Installing RCDefaultApp"
  rcdefaultapp_bootstrap
  echo "Installing Digital Performer"
  digitalperformer_bootstrap
  echo "Installing dpHlepers"
  dphelpers_bootstrap
  echo "Installing the newaudiomac bundle"
  newaudiomac_bundle
}

function yabridge_bootstrap() {
  if ! timed_confirm_yes "Continue with $FUNCNAME?"; then
 local caller="$FUNCNAME"
 mb_ff "$FUNCNAME"; return 0; fi
  if [ -d $HOME/Downloads/yabridge ]; then 
    cp -r $HOME/Downloads/yabridge $HOME/.local/share/
  elif [ -d $HOME/bin/yabridge ]; then 
    cp -r $HOME/bin/yabridge $HOME/.local/share/
  else
    >&2 printf "Cant find yabridge updates in"
    >&2 printf "$HOME/Downloads or $HOME/bin"
  fi
}

function rcdefaultapp_bootstrap() {
  if ! timed_confirm_yes "Continue with $FUNCNAME?"; then
 local caller="$FUNCNAME"
 mb_ff "$FUNCNAME"; return 0; fi
  mkdir -p "$INSTALL_STAGING"
  cd "$INSTALL_STAGING"
  wget https://www.rubicode.com/Downloads/RCDefaultApp-2.1.X.dmg
  if ! type -p bellicose > /dev/null 2>&1; then
    se "RCDefaultApp downloaded to staging, but bellicose not reachable"
    se "you'll need to install it yourself"
    return 1
  fi
  local ts=$(fsts)
  local install_log="$INSTALL_LOGS/RCDefaultApp.$ts.log"
  if bellicose -R "$install_log" install RCDefaultApp-2.1.X.dmg; then
    se "bellicose reported successful install"
    mv RCDefaultApp-2.1.X.dmg "$INSTALLED_SUCCESSFULLY"

    local caller="$FUNCNAME"
    mb_ff "$FUNCNAME"; return 0
  fi
  echo "bellicose did not report a successful install"
  echo "check the log at $install_log"
  return 1
}

# breadcrumbs... for (relatively?) tearfree cross platform setup:
function powerline_bootstrap() {
  if ! timed_confirm_yes "Continue with $FUNCNAME?"; then
 local caller="$FUNCNAME"
 mb_ff "$FUNCNAME"; return 0; fi
  if ! type pipx >/dev/null 2>&1; then
    if ! [ -n "${p3}" ]; then
      if ! p3=$(type -p python3); then
        echo "python3 doesnt seem to be in \$PATH..."
        # TODO: finish
      fi
    fi
  fi
    pipx install powerline-status
    if [ -z "${psh}" ]; then
      # the first line of the output of pipx list contains the location of its venvs
      # we look for the version of powerline.sh with "bash" in its path -- as
      # as opposed to the plain old shell verison.
      if ! psh=$(find $(pipx list |head -n1 |awk '{print$NF}') -name "powerline.sh" 2> /dev/null |grep "bash"); then
        se "cant find powerline.sh, assign psh= and run again"
        return 1
      fi
    fi
    if ! [ -L "$HOME/.local/share/powerline/powerline.sh" ]; then
      mkdir -p "$HOME/.local/share/powerline"
      ln -is "${psh}" $HOME/.local/share/powerline/
    fi

    local caller="$FUNCNAME"
    mb_ff "$FUNCNAME"; return 0
#  else
#    >&2 printf "  on debian based systems, try sudo apt install pipx"
#    >&2 printf "  on mac, install homebrew, then brew cask python; brew cask pipx"
#    >&2 printf "Or something, you know the deal."
#  fi
}

# my basic edits to import-schemes.sh below will detect and add color
# schemes for xfce4-terminal and konsole.  At the bare minimum, I plan
# to add terminator in addition to iTerm which is what the script
# was originally written for, so this function remains generally OS 
# agnostic.
function termschemes_bootstrap() {
  if ! timed_confirm_yes "Continue with $FUNCNAME?"; then
 local caller="$FUNCNAME"
 mb_ff "$FUNCNAME"; return 0; fi
  if ! [ -d "$GH/Terminal-Color-Schemes" ]; then 
    ghc "git@github.com:trustdarkness/Terminal-Color-Schemes.git"
  fi
  cd "$GH/Terminal-Color-Schemes"
  tools/import-schemes.sh
  cd -

  local caller="$FUNCNAME"
  mb_ff "$FUNCNAME"; return 0
}

# in the spirit of consistency, we'll keep these together
function termfonts_bootstrap() { 
  if ! fc-list |grep Hack-Regular; then 
    if [[ $(uname) == "Darwin" ]]; then 
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

  local caller="$FUNCNAME"
  mb_ff "$FUNCNAME"; return 0
}

function term_bootstrap() {
  if ! timed_confirm_yes "Continue with $FUNCNAME?"; then
 local caller="$FUNCNAME"
 mb_ff "$FUNCNAME"; return 0; fi
  termschemes_bootstrap
  termfonts_bootstrap

  local caller="$FUNCNAME"
  mb_ff "$FUNCNAME"; return 0
}

function mullvad_bootstrap() {
  if ! timed_confirm_yes "Continue with $FUNCNAME?"; then
 local caller="$FUNCNAME"
 mb_ff "$FUNCNAME"; return 0; fi
  if [[ uname == "Darwin" ]]; then
    if ! type -p brew > /dev/null 2>&1; then
      se "please make sure brew_bootstrap has run."
      return 1
    fi
    swd=$(pwd)
    mkdir -p "$INSTALL_STAGING"
    cd "$INSTALL_STAGING"
    wget https://mullvad.net/en/download/app/pkg/latest
    wget https://mullvad.net/en/download/app/pkg/latest/signature
    wget https://mullvad.net/media/mullvad-code-signing.asc
    gpg --import mullvad-code-signing.asc
    verify=gpg --verify Mullvad*.asc
    if [ $? -ne 0 ]; then 
      se "Mullvad gpg verification failed."
      cd "$swd"
      return 1
    fi
    if ! sudo installer -pkg Mullvad*.pkg -target /; then 
      se "installer failed with code $?"
      cd "$swd"
      return 1
    else 
      cd "$swd"

      local caller="$FUNCNAME"
      mb_ff "$FUNCNAME"; return 0
    fi
  elif [[ uname == "linux" ]]; then 
    distro="$(lsb_release -d 2>&1|grep Desc|awk -F':' '{print$2}'|xargs)"
    if string_contains "(fedora|nobara)" "$distro"; then
      # Add the Mullvad repository server to dnf
      sudo dnf config-manager --add-repo https://repository.mullvad.net/rpm/stable/mullvad.repo

      # Install the package
      if sudo dnf install mullvad-vpn; then

        local caller="$FUNCNAME"
        mb_ff "$FUNCNAME"; return 0
      fi
    elif string_contains "(Debian|Ubuntu)" "$distro"; then
      # Download the Mullvad signing key
      sudo curl -fsSLo /usr/share/keyrings/mullvad-keyring.asc https://repository.mullvad.net/deb/mullvad-keyring.asc

      # Add the Mullvad repository server to apt
      echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=$( dpkg --print-architecture )] https://repository.mullvad.net/deb/stable $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/mullvad.list

      # Install the package
      sudo apt update
      if sudo apt install mullvad-vpn; then 

        local caller="$FUNCNAME"
        mb_ff "$FUNCNAME"; return 0
      fi 
    else 
      se "couldnt parse distro from $distro, or we dont have setup"
      se "code that is distro specific.  exiting."
      return 1
    fi
  fi
}

function disarm_bootstrap() {
  if ! timed_confirm_yes "Continue with $FUNCNAME?"; then
 local caller="$FUNCNAME"
 mb_ff "$FUNCNAME"; return 0; fi
  if ! disarm=$(type -p disarm); then 
    swd=$(pwd)
    mkdir -p "$INSTALL_STAGING/disarm"
    cd "$INSTALL_STAGING/disarm"
    curl https://newosxbook.com/tools/disarm.tar --output disarm.tar
    tar -xf disarm.tar
    if [[ $(system_arch) == "x86_64" ]]; then 
      cp binaries/disarm.x86 $HOME/.local/bin/
      ln -sf $HOME/.local/bin/disarm.x86 $HOME/.local/bin/disarm
      mkdir -p $HOME/.local/share/multiarch
      cp binaries/* $HOME/.local/share/multiarch/
      path_append "$HOME/.local/share/multiarch/"
      cd "$swd"
      mv "$INSTALL_STAGING/disarm" "$INSTALLED_SUCCESSFULLY"

      local caller="$FUNCNAME"
      mb_ff "$FUNCNAME"; return 0
    fi
  fi
}

function mnlooto_bootstrap() {
  if ! timed_confirm_yes "Continue with $FUNCNAME?"; then
 local caller="$FUNCNAME"
 mb_ff "$FUNCNAME"; return 0; fi
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

      local caller="$FUNCNAME"
      mb_ff "$FUNCNAME"; return 0
    fi
  fi
}

function digitalperformer_bootstrap() {
  if ! timed_confirm_yes "Continue with $FUNCNAME?"; then
 local caller="$FUNCNAME"
 mb_ff "$FUNCNAME"; return 0; fi
  local swd=$(pwd)
  cd "$INSTALL_STAGING"
  lynx -dump https://motu.com/en-us/download/product/489/ > /tmp/dp.txt
  link_numbwe=$(cat /tmp/dp.txt | grep -A11 "Latest Downloads"| grep -A1 "Mac" |tail -n 1|awk -F'(' '{print$1}'|tr '[' ' '|tr ']' ' '|xargs)
  link=$(cat /tmp/dp.txt | grep "^ $link_number"| awk -F"." '{print$2}')
  filename=$(--server-response -q -O - "$link" 2>&1 |
    grep "Content-Disposition:" | tail -1 | 
    awk 'match($0, /filename=(.+)/, f){ print f[1] }' 
  )
  local ts=$(fsts)
  local install_log="$INSTALL_LOGS/$filename.$ts.log"
  if bellicose -R "$install_log" install "$filename"; then 
    se "bellicose reports successful install"
  fi
  # lets double check 
  gout=$(grep "Digital Performer" <(ls /Applications))
  if [ $? -eq 0 ]; then
    mv "$filename" "$INSTALLED_SUCCESSFULLY"
    cd "$swd"

    local caller="$FUNCNAME"
    mb_ff "$FUNCNAME"; return 0
  fi
  echo "bellicose failed to install Digital Performer"
  echo "the logs for the failed attempt can be found at $install_log"
  cd "$swd"
  return 1
}

function dphelpers_bootstrap() {
  if ! timed_confirm_yes "Continue with $FUNCNAME?"; then
 local caller="$FUNCNAME"
 mb_ff "$FUNCNAME"; return 0; fi
  swd=$(pwd)
  ghc git@github.com:trustdarkness/dphelpers.git
  python3 -m venv venv
  . venv/bin/activate
  pip3 install -r requirements.txt
  mkdir -p "$HOME/.local/bin"
  echo "cddph && $HOME/src/dpHelpers/dph debug" > "$HOME/.local/bin/dpd"
  chmod +x "$HOME/.local/bin/dpd"
  cd "$swd"

  local caller="$FUNCNAME"
  mb_ff "$FUNCNAME"; return 0
}

function newaudiomac_bundle() {
 if ! timed_confirm_yes "Continue with $FUNCNAME?"; then
 local caller="$FUNCNAME"
 mb_ff "$FUNCNAME"; return 0; fi
  ts=$(fsts)
  mkdir -p "$INSTALL_STAGING/nam_$ts"
  scp vulcan:/egdod/Backup/Software/MacSoftware/newaudiomac.tar.gz "$INSTALL_STAGING/nam_$ts"
  local swd=$(pwd)
  cd "$INSTALL_STAGING/nam_$ts"
  tar -xf newaudiomac.tar.xz
  trash newaudiomac.tar.xz
  local install_log="$INSTALL_LOGS/newaudiomac.$ts.log"
  if bellicose -R "$install_log" install; then
    # seems unlikely, but you never know
    se "bellicose reports install success. cleaning up."
    mv * "$INSTALLED_SUCCESSFULLY"
    cd "$swd"

    local caller="$FUNCNAME"
    mb_ff "$FUNCNAME"; return 0
  fi
  echo "bellicose failed to install everything in the newaudiomac bundle"
  echo "the logs for the failed attempt can be found at $install_log"
  cd "$swd"
  return 1
}

function mb_ff() {
  local funcname="$1"
  if [ -z $funcname ]; then 
    se "please pass \$FUNCNAME"
    return 1
  fi
  echo "$FUNCNAME finished" >> "$INSTALL_LOGS/mac_bootstrap.log"
}


# TODO: poopulate updated namerefs and use cleanup function in util
function cleanup_macbootstraps() {
  local IFS=$'\a'
  for nameref in "$local_namerefs"; do
    unset $nameref
  done
}
