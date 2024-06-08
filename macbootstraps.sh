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

function cleanup_macbootstraps() {
  local IFS=$'\a'
  for nameref in "$local_namerefs"; do
    unset $nameref
  done
}