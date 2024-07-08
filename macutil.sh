#!/usr/bin/env bash

# Setting PATH for Python 3.12 and to ensure we get modern bash from brew
# in /usr/local/bin before that MacOS crap in /bin
if ! [[ "${PATH}" =~ .*.pathsource.* ]]; then 
  PATH="/usr/local/bin:$HOME/.pathsource:$HOME/.local/bin:/Library/Frameworks/Python.framework/Versions/3.12/bin:${PATH}"
fi

HOMEBREW_NO_INSTALL_FROM_API=1 
export EDITOR=vim

# D is the path to this directory, usually on my systems, should be
# $HOME/src/github/dots, but if not set, some things not happy
if [ -z "${D}" ]; then
  D=$(dirname "${BASHSOURCE[0]}")
  if ! [ -f "$D/util.sh" ]; then 
    >&2 printf "Tried to set D=${D} but no util.sh"
    >&2 printf "there perhaps be dragons..."
  fi
fi

# definition of modern bash to at least include associative arrays
# and pass by reference
MODERN_BASH="4.3"

# more date formats that don't seem to be mac specific in util.sh
MACFILEINFODATEFMT="%m/%d/%Y %T"
MACOS_LOG_DATEFMT="%Y-%m-%d" # used by the "log" command

# FSDATEFMT and FSTSFMT in util.sh
function fsdate_to_logfmt {
  to_convert="${1:-}"
  date -f "${FSDATEFMT}" "${to_convert}" +"${MACOS_LOG_DATEFMT}"
}

function fsts_to_logfmt {
  to_convert="${1:-}"
  date -f "${FSTSFMT}" "${to_convert}" +"${MACOS_LOG_DATEFMT}"
}

alias bi="bellicose install"
alias bvi="bellicose -v install"
alias bSi="bellicose -S install"
alias bu="bellicose unarchive"
bRi() { bellicose -R "${1:-}" install; }
bRu() { bellicose -R "${1:-}" unarchive; }
bSRi() { bellicose -S -R "${1:-}" install; }
_s="$HOME/Downloads/_staging"

# its expected that all of these files will be sourced and in the env
# ... kind of ridiculous and needs to be paired down
BASH_PARENT_SOURCED=(
  "$HOME/.profile"
  "$HOME/.bash_profile"
  "$HOME/.bashrc"
  "$D/.globals" # usually symlinked at $HOME/.globals
  "$D/util.sh"
  "$D/macutil.sh"
  "$D/.user_prompts.sh"  
)

# these are sourced on demand, but generally used sooner or latrer
BASH_SOURCE_ON_DEMAND=(
  "$D/installutil.sh"
  "$D/localback.sh"
  "$D/appleservices.sh"
  "$D/bellicose.sh" # bellicose is an executable and really be sourced anymore
                    # though some functionality may move into installutil.sh
                    # when bellicose gets its own repo
)

# for MacOS's zsh nag text
BASH_SILENCE_DEPRECATION_WARNING=1

# this is used in localback.sh
OLDHOME="/Volumes/federation/Users/mt"

# where pref(s)_reset will replicate directories (under .*Library/)
# and backup plist and other files before removing them
PREFS_DISABLED="$HOME/Library/disabled"

# for pref_change (maybe currently non-functional)
DEFAULT_CHANGE_OPTIONS=( "disable" "trash" )
DEFAULT_CHANGE="disable"

FONTDIRS=(
  "/Library/Fonts"
  "$HOME/Library/Fonts"
  "/System/Library/Fonts"
)

# we maintain a local cache of brew info --json --eval-all in a file
# in this directory with the format eval-all.%Y&m&d.json
BREW_SEARCH="$HOME/.local/share/brew-search"

# for convenience and because the commands are different than GNU
alias du0="du -h -d 0"
alias du1="du -h -d 1"

# because I can never get the boot key combos, or its a bluetooth keyboard
# or I want to feel like an adult
alias reboot_recovery="sudo /usr/sbin/nvram internet-recovery-mode=RecoveryModeDisk && sudo reboot"
alias reboot_recoveryi="sudo nvram internet-recovery-mode=RecoveryModeNetwork && sudo reboot"
# untested; https://apple.stackexchange.com/questions/367336/can-i-initiate-a-macos-restart-to-recovery-mode-solely-from-the-command-line
alias reboot_recovery="sudo nvram 'recovery-boot-mode=unused' && sudo reboot"

# use at your own risk
alias uncodesign="codesign -f -s -"

# https://shadowfile.inode.link/blog/2018/08/autogenerating-defaults1-commands/
alias plcat='plutil -convert xml1 -o -'

# again, for convenience, see github.com/trustdarkness/dpHelpers for more
plugins="/Library/Audio/Plug-Ins"
userplugins="$HOME$plugins" 
uservst="$userplugins/VST"
uservst3="$userplugins/VST3"
userau="$userplugins/Components"
sysvst="$plugins/VST"
sysvst3="$plugins/VST3"
sysau="$plugins/Components"

VSTEXT='vst'
VST3EXT='vst3'
AUEXT='component'
VST3REGEX=".*.${VST3EXT}$"
VSTREGEX=".*.${VSTEXT}$"
AUREGEX=".*.${AUEXT}$"
REGEXES=( "${VST3REGEX}" "${VSTREGEX}" "${AUREGEX}" )

# extended regex seems a bit more reliable for or groups
# requires egrep, find -E, grep -E, etc
printf -v PLUGIN_EREGEX '(%s|%s|%s)' "${REGEXES[@]}"

# setup the environment and make functions available from dpHelpers
function cddph() {
  DPHELPERS="$HOME/src/dpHelpers" 
  sleep 1
  cd "$DPHELPERS" 
  source "$DPHELPERS/lib/bash/lib_dphelpers.sh" 
  source "$DPHELPERS/lib/bash/lib_plugins.sh"
}
export -f cddph

APP_FOLDERS=( 
  "/Applications" 
  "/Volumes/Trantor/Applications" 
  "/System/Applications"
  "$HOME/Applications"
)

# for functions that need to operate on the root filesystem when
# its not root (such as when working under the conditions of 
# csrutil authenticated-root disable), the following global will
# be used in place of root.
FAKEROOT=$HOME/rootfs

function load_services() {
  source "$D/macservices.sh"
}
alias s="load_services"

# Sets the position of the Dock and restarts the Dock
# Args: string, one of left, right, bottom, no error checking 
# writes the default 'orientation' to 'com.apple.dock' && pkill Dock
function dockpos() {
  defaults write 'com.apple.dock' 'orientation' -string ""${1:-}""
  pkill Dock
}

# like many of the functions here, mostly to remind myself that it exists
function defaults_find() {
  defaults find $@
}

# Finds apps that have written entries to "favorites"
# no args or explicit return, runs defaults find LSSharedFileList
function favorites_find_apps() {
  defaults find LSSharedFileList
}

# for compatibility with the similar linux command
function fc-list() {
  sterm="${1:-}"
  declare -a args
  if [ -n "${sterm}" ]; then
    args+=("-iname")
    printf -v glob '"*%s*' "${sterm}"
    args+=("${glob}")
  fi
  for dir in "${FONTDIRS[@]}"; do 
    find "${dir}" "${args[@]}"
  done
}

# Takes an array of plist files similar to above and backs up those
# files to PREFS_DISABLED before deleting them.
# on individual file failure, returns code from pref_reset,
# otherwise 0
function prefs_reset() {
  prefs_arr_name=$1[@]
  prefs=("${!prefs_arr_name}")
  for file in "${prefs[@]}"; do 
    pref_reset "${file}"
  done
  pkill Finder
  return 0
}

# Takes a plist file, copies to PREFS_DISABLED, and deletes
# returns any failure codes from mkdir -p or mv, otherwise 0
# This runs using fakeroot, so when not messing with csrutil 
# authenticated-root disable, FAKEROOT should be set to /
function pref_reset() {
  file="${1:-}"
  if [ -f "${file}" ]; then
    if [[ "${file}" =~ ^/Library ]]; then 
      disabled_dir="${PREFS_DISABLED}/global/Library/$(dirname "${file}"|basename)"
    elif [[ "${file}" =~ ^/System ]]; then 
      disabled_dir="${PREFS_DISABLED}/System/Library/$(dirname "${file}"|basename)"
    else
      disabled_dir="${PREFS_DISABLED}"/$(dirname $(echo "${file}" |sed "s:$HOME/Library/::"))
    fi
    if ! mkdirret=$(mkdir -p "${disabled_dir}"); then 
      se "mkdir -p \"${disabled_dir}\" returned ${ret}"
      return ${mkdirret}
    fi
    if ! mvret=$(sudo mv "${file}" "${disabled_dir}"); then
      se "mv \"${file}\" \"${disabled_dir}\" returned ${mvret}"
      return ${mvret}
    else
      echo "${file} has been removed and services should no longer start."
    fi
  fi
}

# https://stackoverflow.com/questions/16375519/how-to-get-the-default-shell
function getusershell() {
  dscl . -read ~/ UserShell | sed 's/UserShell: //'
}

# an example for above, runs pres reset on finder_prefs
function finder_reset() {
  prefs_reset finder_prefs
}

# Updates the locally stored brew --json --eval-all unconditionally
function brew_update_cache() {
  se "updating local cache..."
  fsdate=$(date +$FSDATEFMT)
  mkdir -p $BREW_SEARCH
  brew info --json=v1 --eval-all > "$BREW_SEARCH/eval-all.$fsdate.json"
}

# searches brew using the local json cache (as opposed to brew search)
# updating the cache if its > 7 days
function brew_regex_search() {
  regex="${1:-}"
  current_cache=$(most_recent_in_dir $BREW_SEARCH)
  parts=($(split $current_cache '.'))
  cached_date="${parts[1]}"
  if is_older_than_1_wk $cached_date; then 
    brew_update_cache
    current_cache=$(most_recent_in_dir $BREW_SEARCH)
  fi
  query=$(singlequote $(printf 'map(select(.name | test ("%s"))|.name)' "${regex}"))
  cat $current_cache|jq "${query}"
}

# runs du, asking for sudo if needed for the specified dirs
# always with -h, with other opts if you provide them 
# before the directory
function xdu() {
  opts=( "-h" )
  if [ $# -gt 1 ]; then 
    local dir="${2:-}"
    if [[ "${1:-}" == "-s" ]] && [[ $# == 2 ]]; then 
      sudo du "${opts[@]}" "${dir}"
    elif [[ "${1:-}" == "-s" ]] && gt $# 2; then 
      shift 
      shift
      sudo du "${opts[@]}" $@ "${dir}"
    elif [ -d ""${1:-}"" ]; then
      local dir="${1:-}"
      shift  
      sudo du "${opts}" $@ "${dir}"
    fi
  elif [ $# -eq 1 ]; then 
    local dir="${1:-}"
    if [ -d "${dir}" ]; then 
      can_i_read "${dir}"
      if [ $? -eq 0 ]; then 
        du "${opts[@]}"
      else
        sudo du "${opts[@]}"
      fi
    fi
  fi
}

# no idea what I was trying to accomplish here
# trying to replicate du on linux?
function dul() {
  if [[ "${1:-}" == "-s" ]]; then
    local dir=$2
    local sudo=true
  else
    local dir="${1:-}"
    local sudo=false
  fi
  if [ -d "${dir}" ]; then 
    if ${sudo}; then 
      xdu -s "${dir}" -d 0
    else
      xdu "${dir}" -d 0
    fi
  fi
}

# du -h --max-depth=0 on linux?
function du0() {
  dul "${1:-}" -d 0 
}

# du -h --max-depth=0 on linux? but with sudo?
function sdu0() {
  dul -s "${1:-}" -d 0 
}

# du -h --max-depth=1 on linux?
function du1() {
  dul "${1:-}" -d 1
}

# du -h --max-depth=1 on linux? but with sudo?
function sdu1() {
  dul -s "${1:-}" -d 1
}

# uses find to determine if the current user has read permissions
# recursively below the provided directory
# returns 0 if readable, return code of can_i_do if not
function can_i_read() {
  can_i_do "${1:-}" 555 $2
}

# uses find to determine if the current user has write permissions
# recursively below the provided directory
# returns 0 if writeable, return code of can_i_do if not
function can_i_write() {
  if [ -d ""${1:-}"" ]; then 
    whoowns=$(ls -alh "${1:-}"|head -n2|tail -n1|awk '{print$3}')
    if [[ "${who}" == "$(whoami)" ]]; then
      can_i_do "${1:-}" 200 1
      return $?
    else
      grpowns=$(ls -alh "${1:-}"|head -n2|tail -n1|awk '{print$4}')
      if [[ "${grpowns}" == "$(whoami)" ]]; then
        can_i_do "${1:-}" 020 1
        return $?
      else
        can_i_do "${1:-}" 002 1
        return $?
      fi
    fi
  fi
  return 1
}

# uses find to determine if the current user has given permissions
# recursively below the provided directory
# Args: 
#  1 - directory name
#  2 - umask
#  3 - depth - defaults to all
# returns 0 if perms match, 127 if unable to write basedir, 1 otherwise
function can_i_do() {
  local dir="${1:-}"
  local mask="${2:-}"
  local depth="${3:-all}"
  if [ -d "${dir}" ]; then 
    local ts="$(date '+%Y%m%d %H:%M:%S')"
    local tempfile="/tmp/permcheck-${ts}"
    local temppid="/tmp/pid-${ts}"
    local tempfin="/tmp/fin-${ts}"
    (
    echo $$ > "${temppid}"
    if is_int "${depth}"; then
      find "${dir}" -depth "${depth}" -perm -555 2>&1 > "${tempfile}"
    elif [[ "${depth}" == "all" ]]; then 
      find "${dir}" -perm -555 2>&1 > "${tempfile}"
    else
      >&2 printf "couldn't understand your second parameter, which should be "
      >&2 printf "depth, either an int or \"all\""
      return 1
    fi
    echo $? > "${tempfin}"
    )
    while ! test -f "${tempfin}"; do 
      sleep 1
      cat "${tempfile}"|grep "Permission denied"
      if [ $? -eq 0 ]; then 
        kill $(cat "${temppid}")
        return 127
      fi
    done
    if [ -f "${tempfin}" ]; then
      return $(cat "${tempfin}")
    fi
    return 0
  else
    >&2 printf "Please supply a path to check"
  fi
}

# used to be I receieved .command files on the MacOS for certain things
# and everything but the sudo commands was nonsense boilerplate.
# this function reads such a file (in the current directory, more than
# one if they're there), and runs only the sudo commands.  It does no
# sanity checking... if someone gets you to run rm -rf /, that's on you.
function sudo_only_commands  {
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

# tells the finder to show hidden files and restarts it.
# writes AppleShowAllFiles true to com.apple.finder 
function showHidden {
  writeAndKill() {
    defaults write com.apple.finder AppleShowAllFiles true
    killall Finder
  }
 if isShown=$(defaults read com.apple.finder AppleShowAllFiles > /dev/null 2>&1); then
    case "$isShown" in
      "false"|"no"|""|0)
        writeAndKill
        ;;
      "true"|"yes"|1)
        se "Finder already set to show all files, kill anyway?"
        if confirm_yes "(Y/n)"; then 
          killall Finder
        fi
        ;;
      *)
        se "defaults read com.apple.finder AppleShowAllFiles returned $isShown"
        return 1
        ;;
    esac
  else
    writeAndKill
  fi
} 

OLDSYS="/Volumes/federation"
OLDHOME="/Volumes/federation/Users/$(whoami)"
F="/Volumes/federation/Users/mt/Downloads"
# sources localback so that its functions are available in the working env
function b() {
  source $D/localback.sh
}

# Creates a Mac alias to the provided application in /Applications
function appalias() {
  local target="${1:-}"
  if [ -n "${target}" ]; then
    if stat "${target}"; then
      local tbase=$(basename "${target}")
      tq=$(printf '%s' "${target}")
      tbq=$(printf '%s' "${tbase}")
  cat <<END
tell application "Finder"
set myApp to POSIX file "${tq}" as alias
make new alias to myApp at "Babylon:Applications"
set name of result to "${tbq}"
end tell 
END
  echo "return $?"
    fi
  fi
}

# returns 0 if the provided string is a path valid for Applescript
function isvalidapplepath() {
  local path="${1:-}"
  if [[ -n "${path}" ]]; then 
    printf -v applepath '"%s"' "${path}"
    test=$(osascript -e "list folder ${applepath}")
    return $?
  fi
  return 1
}

# Creates a mac style alias of target at dest
# Args:
#  1 target
#  2 dest
# returns exit status from osascript, 0 if successful
function anyalias() {
  local target="${1:-}"
  local dest="${2:-}"
  if [ -n "${target}" ]; then
    if r=(stat "${target}"); then
      local tbase=$(basename "${target}")
      tq=$(printf '%s' "${target}")
      tbq=$(printf '%s' "${tbase}")
      if [ -d "${dest}" ]; then 
        r=! $(echo "${dest}"|grep '^\/.*')
        if $?; then 
          dn=$(dirname "${dest}")
          if [[ "${dn}" == "." ]]; then 
            absposixpath="${pwd}/${dest}"
          elif ! r=$(echo "${dn}"|grep '^\/.*'); then
            absposixpath="$(pwd)/${dn}/${dest}"
          elif r=$(echo "${dn}"|grep '^\/.*'); then
            absposixpath="${dn}/${dest}"
          else
            >&2 printf "Couldn't make an absolute path form ${dest}"
            return 1
          fi
        else
          absposixpath="${dest}"
        fi
        applepath=$(echo "${absposixpath:1}"|tr '/' ':')
        if isvalidapplepath "${applepath}"; then 
          if can_i_write "${absposixpath}"; then 
  osascript <<END
tell application "Finder"
set myApp to POSIX file "${tq}" as alias
make new alias to myApp at "${applepath}"
set name of result to "${tbq}"
end tell 
END
  echo "return $?"
              else
  sudo osascript <<END
tell application "Finder"
set myApp to POSIX file "${tq}" as alias
make new alias to myApp at "${applepath}"
set name of result to "${tbq}"
end tell 
END
  echo "return $?"

          fi
        fi
      fi
    fi
  fi
}

# creates a Mac style alias of a VST3 plugin in the system plugins folder
function vst3alias() {
  local target="${1:-}"
  if [ -n "${target}" ]; then
    if stat "${target}"; then
      local tbase=$(basename "${target}")
      tq=$(printf '%s' "${target}")
      tbq=$(printf '%s' "${tbase}")
  osascript <<END
tell application "Finder"
set myPlug to POSIX file "${tq}" as alias
make new alias to myPlug at "Foundation:Library:Audio:Plug-Ins:VST3"
set name of result to "${tbq}"
end tell 
END
        return $?
    fi
  fi
}

# Shows launchds logs since the last reboot
function show_last_boot_logs() {
  last_reboot_lastfmt=$(last reboot |head -n1 |awk '{print$3 $4 $5 $6}')
  last_reboot_logfmt=$(date -f +"$LAST_DATEFMT" -d "last_reboot_lastfmt" +"$MACOS_LOG_DATEFMT")
  log show --predicate "processID == 0" --start $last_reboot_logfmt --debug
}

# resets tdd dialogs for the given app
# args: app name -- it does search to see if we think this is a valid app
function reset_tcc_dialogs() {
  local app="${1:-}"
  if isapp "${app}"; then 
    tccutil reset All "${app}"
  fi
}

# prints a long form verbose=3 codesign response to the console
function codesign_get() {
  codesign -dv --verbose=3 "$@" 2>&1 
}

# prints the cdhash itself to the console
function get_codesig() {
  codesign -dv --verbose=3 "$@" 2>&1 |grep '^CDHash='|awk -F'=' '{print$2}'
}

# Returns 0 if the file provided as arg1 is a pkg (or mpkg) installable
# by the macos installer program
function ispackage() {
  file="${1:?Please provide a file}"
  if [ -f "${file}" ]; then 
    if [[ "${file}" =~ .*.[m]?pkg$ ]]; then 
      if out=$(installer -pkg "${file}" -pkginfo); then 
        return 0
      else
        return 1
      fi
    fi
  fi
  return 1
}

# We'll define an app for these purposes as a Mach-O app bundle ending in 
# .app Developer.apple.com defines:
# Mach-O is the native executable format of binaries in OS X and is the 
# preferred format for shipping code.   An app bundle is a directory with
# at minimum the contents Contents/MacOS/${appexename}
# Args: path to application to verify it fits the definition.
# returns 0 if app, 1 otherwise.
function isapp() {
  is_machO_bundle "${1:-}" # there must be a more complete heuristic than this
  return $?
}

function is_machO_bundle() {
  bundledir="${1:?Please provide full path to a bundle or .app file}"
  if machO=$(stat "${bundledir}/Contents/MacOS"); then
    confirmed_machO_bundle=$(codesign_get "${bundledir}" \
      |grep "Mach-O"|grep "bundle"|awk -F'=' '{print$2}')
    # redundant, but handles return readably
    grep "bundle" <<< "${confirmed_machO_bundle}"
    if [ $? -eq 0 ]; then 
      se "is ${confirmed_machO}"
      return 0
    fi
  fi
  return 1
}

# Executables are also Mach-O, but not bundles, meaning no .app, 
# not direcotries.  How we've defined things, apps and executables
# are disjoint
# Args: name to confirm is executable
# returns 0 if so, 1 otherwise
function isexe() {
  exe="${1:?Please provide full path to executable binary}"
  if [ -f "${exe}" ]; then 
    # MachO bundle .apps will be dirs
    confirmed_machO_nobundle=$(codesign_get "${bundledir}" \
      |grep "Mach-O"|grep -v "bundle"|awk -F'=' '{print$2}')
    # redundant, but handles return readably
    grep -v "bundle" <<< "${confirmed_macho_nobundle}"
    if [ $? -eq 0 ]; then 
      se "is ${confirmed_machO}"
      return 0
    fi
    mach_header=$(binmachheader "${exe}"| awk '{print $2 $5}') 
    gout=$(grep "EXECUTE" <<< "${mach_header}")
    gret=$?
    echo "${mach_headers}"
    return ${gret}
  fi
  return 1
}

# Application in this function represents the union of apps and 
# executables as defined above. TODO: consider replacing this with 
# something more robust or comprehensive using info from launchctl
# Args: name to confirm is executable or app
# returns 0 if so, 1 otherwise
function isapplication() {
  local maybeapp="${1:-}"
  if [ -d "${maybeapp}" ]; then 
    bundledir="${maybeapp}"
  elif [ -d "/Applications/${maybeapp}" ]; then 
    bundledir="/Applications/${maybeapp}"
  elif [ -f "${maybeapp}" ]; then 
    exe="${maybeapp}"
  elif exe=$(type -p "${maybeapp}"); then 
    exe="${maybeapp}"
  fi
  if machO=$(stat "${bundledir}/Contents/MacOS"); then
    confirmed_machO=$(codesign_get "${bundledir}"|grep "Mach-O"|awk -F'=' '{print$2}')
    if [ $? -eq 0 ]; then 
      se "is ${confirmed_machO}"
      return 0
    fi
  elif executable=$(binmachheader "${file}"); then 
    se "$machO"
    return 0
  fi
  return 1
}

# Using definition of app from isapp, search APP_FOLDERS for an app that 
# the search term globs to.  TODO: consider replacing this with 
# something more robust or comprehensive using info from launchctl
# Args: search term
# echos matched apps back to the shell. no explicit return
function findapp() {
  local st="${1:-}"
  found=()
  
  for folder in "${APP_FOLDERS[@]}"; do 
    while IFS= read -r -d $'\0'; do
      found+=("$REPLY") # REPLY is the default
    done < <(find "${folder}" -depth 1 -iname "*${st}*" -regex '.*.app$' -print0 2> /dev/null)
  done
  for app in "${found[@]}"; do 
    echo "${app}"
  done
}

# Glob searches for an app (using findapp) and if found, adds it to 
# a disabled label in gatekeeper.  If gatekeeper is enabled, this can
# keep the app from running.  If you're not parental controlling still
# useful for default apps (like Music)
# args: search term
# returns retcode from spctl
function gatekeeper_disable_app() {
  local st="${1:-}"
  foundblob=$(findapp "${st}"|tr "'" "")
  founds=()
  if [ -n "${foundblob}" ]; then
    IFS='\n' read -r -a founds <<< "${foundblob}"
  fi
  ctr=0
  if gt ${#founds} 1; then 
    for found in "${founds[@]}"; do 
      ((ctr++))
      echo "${ctr}. ${found}"
    done
    ((ctr++))
    echo "${ctr}. All"
    echo " "
    echo "Which would you like to disable?"
    response=$(get_keypress "")
    echo " "
    if is_int ${response}; then 
      if [ ${response} -eq ${ctr} ]; then 
        for found in "${founds[@]}"; do
          echo "disabling ${found}"
          sudo spctl --add --label 'DeniedApps' "${found}"
          return $?
        done
      else
        ((ctr++))
        if lt ${response} ${ctr}; then       
            echo "disabling ${founds[${response}]}"
            sudo spctl --add --label 'DeniedApps' "${founds[${response}]}"
            return $?
        fi
      fi
    fi
    >&2 printf "couldnt understand your input"
    return 1
  elif [ ${#founds[@]} -eq 1 ]; then
    echo "disabling ${founds[0]}"
    gatekeeper_disable_known_app "${founds[0]}"
    return $?
  else
    >&2 printf "but i still couldn't find what you're looking for"
  fi
}

# Adds an app to the DeniedApps label in gatekeeper, which should prevent
# it from running when gatekeper itself is enabled. No sanity checking.
# args: App name
# returns retcode from spctl
function gatekeeper_disable_known_app() {
  sudo spctl --add --label 'DeniedApps' ""${1:-}""
}

# Removes the DeniedApps label from a given app, such that when gatekeeper 
# is enabled, it no longer interferes with that app
# args: App name
# returns retcode from spctl
function gatekeeper_enable_known_app() {
  sudo spctl --remove label 'DeniedApps' '"${1:-}"'
}

# Attempts using gatekeeper against a list of services to add the DeniedApps
# label such that gatekeeper should prevent them from running.  This has 
# not been extensively tested 
# args: array name (not ref) whos members should be disabled
# returns retcode from spctl
function gatekeeper_disable_services() {
  local -n name="${1:-}"[@]
  local services=( "${!name}" )
  fails=0
  for service in "${services[@]}"; do
    if out=$(codesign_read "${service}"); then
      gatekeeper_disable_known_app "${service}"
    else
      if lt ${fails} 1; then
        se "apple services were manually discovered on BigSur, ymmv"
      fi
      se "%s does not appear to be valid on your system." "${service}"
      ((fails++))
    fi
  done
  return ${fails}
}

# Adds the DeniedApps label to an app based on its cdhash such thhat
# gatekeeper should prevent it from running
# args: cdhash 
# returns retcode from spctl
function gatekeeper_disable_cdhash() {
  sudo spctl --add --label 'DeniedApps' --hash "${1:-}"
}

# Disables sip, must be run from recovery mode, returns
# code from csrutil, 0 if successful.  If necessary, will run 
# csrutil disable --no-internal
function sipdisable() {
  out=$(csrutil disable)
  if [ $? -gt 0 ]; then
    # unable to test this, I'm just being thorough
    internal=$(echo "${out}" | grep "Apple"|grep -i "internal" |grep -i "enabled")
    if [ -n "${intnernal}" ]; then
      # https://github.com/SpaceinvaderOne/Macinabox/issues/77
      csrutil disable --no-internal
      return $?
    fi
  else 
    return 0
  fi
  return 1
}

# Enables SIP, but allows a debugger to attach to processes without 
# the get-task-allow entitlement and allows dtracing of system procs. 
# --without debug dtrace
function sip_enable_allow_debug() {
  csrutil enable --without debug dtrace
}

# Enables SIP while allowing non-entitled apps filesystem access
function sip_enable_without_fs() {
  csrutil enable --without fs
}

# Enables SIP but still allows loading kexts
function sip_enable_allow_kexts() {
  csrutil enable --without kext
}

# Allows rw access to nvram with SIP enabled
function sip_enable_allow_nvram() {
  csrutil enable --without nvram
}

# https://theapplewiki.com/wiki/System_Integrity_Protection
# Enables sip but allows:
# - rw access to nvram 
# - filesystem access to non-entitled apps
# - dtrace for system procs
# - attach debugger to apps without get-task-allow
function sip_permissive_mode() {
  csrutil enable --without debug dtrace fs nvram # kext
}

# Adds an app to the gatekeeper DeniedApps label and disables based
# on the same label.
function disableapp() {
  add_disable_app "${1:-}"
  if [ $? -eq 0 ]; then
    sudo spctl --disable --label 'DeniedApps' 
  fi
}

# Show entitlements for the given app
function entitlements_show() {
  local app="${1:-}"
  if isapp "${app}"; then 
    # https://eclecticlight.co/2021/01/07/notarization-the-hardened-runtime/
    codesign --display --entitlements :- "${app}"
  fi
}

# library validation is an entitlement that makes it such that only known, 
# inspected libraries can be loaded (much like codesigning does in general
# for apps) and that apps can only load validated libraries that they are 
# approved for.  So if certain parts of an app are failing, a video driver,
# third party extension, because of a crack, etc, this could be helpful.
# It also does increase the risk of running your system.  If this plist 
# edit does not seem sufficient, you may need a kernel patch, see:
# https://github.com/mologie/macos-disable-library-validation
function disable_library_validation() {
  sudo defaults write /Library/Preferences/com.apple.security.libraryvalidation.plist DisableLibraryValidation -bool true
}

# Enables library validation (the default)
function enable_library_validation() {
  sudo defaults write /Library/Preferences/com.apple.security.libraryvalidation.plist DisableLibraryValidation -bool false

}

# Allows for developer extensions to be loaded into the kernel
function devexts() {
  # likely also requires sip enable --without kexts
  systemextensions developer on
}

# Disable gatekeeper assessments.  Note: the system continues
# to run and assessments are still performed on kernel loads,
# but not on executabels, installers, or files.  The 
# System Preferences Privacy pane should now show apps can be
# opened from anywhere.
function gatekeeper_global_disable() {
  sudo spctl --global-disable
}

# This was the expected disable command on 10.15.7 and below,
# it still functions and seems to provide identical functionality
# to global-disable, though this has not been extensively verified
function gatekeeper_master_disable() {
  sudo spctl --master-disable
}

# Re-enables gatekeeper assessments.
function gatekeeper_global_enable() {
  sudo spctl --global-enable
}

# Re-enables gatekeeper assessments.  Seems to be interchangeable
# with gatekeeper global-enable.
function gatekeeper_master_enable() {
  sudo spctl --master-enable
}

# Shows status of gatekeeper assessments as the apply to 
# app execution, package install, and file openening.
function gatekeeper_status() {
  spctl --status
}

# Shows the status of gatekeepers facility to get user consent
# before inserting a kernel module.
function gatekeeper_kext_status() {
  spctl kext-consent status
}

# returns all the current rules set or known to gatekeeper
function gatekeeper_list_rules() {
  spctl --list
}

# returns 0 if $1 is a path to a VST, VST3, or Component 
# audio plugin (based on a regex, does not look to see if
# its in a known location), 1 otherwise
function is_audio_plugin() {
  totest="${1:-}"
  err_machO="Audio plugins should be folders (Mach-O bundles)"
  if [ -d "${totest}" ]; then
    if ! is_machO_bundle "${totest}"; then 
      se "$err_machO"
      return 1
    fi
    grep -E "${PLUGIN_EREGEX}" <<< "${totest}" > /dev/null
    return $?
  else
    se "$err_machO"
    return 1
  fi
}

# runs a gatekeeper assessment on a given file (arg1) for a given type (arg2)
# prints the result to the console.  no explicit return.
function gatekeeper_assess() {
  file="${1:?provide a file to assess. Assumes type execute, override with arg2}"
  type="${2:execute}" # valid types: execute install open
  if [ -d "${file}" ] && [[ "${type}" == "execute" ]]; then
    if isapp "${file}"; then 
      spctl -a "${file}" -t "${type}"
    elif is_audio_plugin "${file}"; then 
      spctl -a "${file}" -t "open"
    fi
  elif [ -f "${file}" ]; then 
    if [[ "${type}" == "execute" ]]; then 
      cdhash=$(codesign_read_cdhash "${file}")
      spctl -a "${cdhash}" -t "${type}"
    elif ispackage "${file}"; then 
      spctl -a "${file}" -t "install"
    else
      spctl -a "${file}" -t "open"
    fi
  fi
}

# Tells XCode that it is now located somewhere else (say, on an external drive)
# though XCode doesn't love being on an external drive, no guarantee 
# everything will work.  YMMV.
# Args: location of the new home, can be a path to XCode.app or its parent dir
# Returns 0 if everything completed successfully, 1 otherwise.
function xcode_rehome() {
  # https://stackoverflow.com/questions/59159232/can-i-install-xcode-on-an-external-hard-drive-along-with-the-iphone-simulator-ap
  local new_home="${1:-}"
  if [[ "${new_home}" == *"Xcode.app" ]]; then 
    xcodesel="${new_home}/Contents/Developer"
  elif [ -f "${new_home}/Xcode.app" ]; then
    xcodesel="${new_home}/Xcode.app/Contents/Developer"
  fi
  if [ -z "${xcodesel}" ]; then 
    >&2 printf "Try again, with the /path/to/Xcode.app\n"
    return 1
  fi
  sudo xcode-select -s "${xcodesel}"
  bash && /usr/bin/xcrun --find xcodebuild
  return 0
}

# If authenticated root is enabled (the boot volume is immutable), 
# disables it (assuming we're in recovery) after printing a warning.
function pre_system_edit() {
  if boot_volume_is_immutable; then 
    >&2 printf "This will enable you to make modifications to the system volume\n"
    >&2 printf "but you will be unable to boot until you re-bless the system.\n"
    >&2 printf "\n"
    >&2 printf "The proper routines are in post-system-edit.\n"
    csrutil authenticated-root disable
    return $?
  else
    >&2 printf "authenticated root is already disabled"
    return 0
  fi
}

# Simulates rebooting holding the option key --
# boots to the boot disk picker
function boottostartoptions() {
  sudo /usr/sbin/nvram manufacturing-enter-picker=true
  sudo reboot
}

function reboot_target_disk_mode() {
  sudo nvram target-mode=1
  sudo reboot
}

# boots the system normally after having set nvram to
# boot to the picker
function boottostartupdisknooptions() {
  sudo /usr/sbin/nvram manufacturing-enter-picker=false
  sudo reboot
}

# Disables the spotlight metadata service
function disable_mds() {
  sudo mdutil -a -i off
}

# enables the spotlight metadata service
function enable_mds() {
  sudo mdutil -a -i on
}

function lsmod() {
  # https://discussions.apple.com/thread/254538333?sortBy=best
   /usr/bin/kmutil showloaded --no-kernel-components --list-only
}

# dumps a codesign verbose 3 output to the terminal
function codesign_read() {
  codesign -dv --verbose=3 "${1:-}" 2>&1
}

# prints the cdhash of a given bundle
function codesign_read_cdhash() {
  codesign_read "${1:-}" |grep '^CDHash='|awk -F'=' '{print$2}'
}

# prints the executable for the given bundle
function codesign_read_executable() {
  codesign_read "${1:-}" |grep '^Executable='|awk -F'=' '{print$2}'
}

# replaces the codesign signature for the given bundle
function codesign_replace() {
  codesign --force --deep --sign - "${1:-}"
}

# removes the quarantine bit if set
function quarantine_remove() {
  sudo xattr -r -d com.apple.quarantine "${1:-}"
}

# gets the domains on the current system
function domains_read() {
  defaults domains |tr ',' '\n'
} 

# searches the domains on the current system for the given term
function domains_search() {
  domains_read |grep "${1:-}"
  return $?
}

# prints the date in a format suitable for use in plist files
function plist_date_fmt() {
  echo "YYYY-MM-DDThh:mm:ssZ"
  return 0
}

# disable spotlight indexing
# https://apple.stackexchange.com/questions/388882/how-to-disable-spotlight-and-mds-stores-on-mac-os-catalina
function spotlight_disable_indexing() {
  sudo mdutil -v -a -i off
  return $?
}

# disable spotlight searching
function spotlight_disable_searching() {
  sudo mdutil -v -a -d
  return $?
}

service () {
  if undefined "service_list"; then 
    unset -f service ssr
    source "$D/macservices.sh"
  fi
  service "$@"
  return $?
}

ssr() {
  if undefined "service_list"; then 
    unset -f ssr service
    source "$D/macservices.sh"
  fi
  ssr $D
}

# Kills all apps and gives the user a fresh session without
# requiring a reboot
function killallapps() {
  launchctl reboot apps
  return $?
}


# Does a full reboot without allowing any apps to block 
# on save, etc
function reboot_fast() {
  launchctl reboot logout
  return $?
}

# asks launchctl to teardown userspace and rebuild without
# doing a full reboot
function reboot_userspace() {
  launchctl reboot userspace
  return $?
}

# asks launchctl to teardown userspace and bring up single user
# without executing a full reboot
function reboot_single_userspace() {
  launchctl reboot userspace -s
  return $?
}

# asks launchctl to reboot in single user
function reboot_single() (
  lacunchctl reboot system -s
  return $?
)

# Modified from 
# https://stackoverflow.com/questions/3572030/bash-script-absolute-path-with-os-x
# echos to console absolute path for the given relative path, following symlinks as
# appropriate
function realpath() (
  OURPWD=$PWD
  cd "$(dirname ""${1:-}"")"
  LINK=$(readlink "$(basename ""${1:-}"")")
  if [[ "$LINK" == "/" ]]; then 
    cd "$OURPWD"
    echo "$LINK"
    return 0
  fi
  while [ "$LINK" ]; do
    cd "$(dirname "$LINK")"
    LINK=$(readlink "$(basename ""${1:-}"")")
  done
  REALPATH="$PWD/$(basename ""${1:-}"")"
  cd "$OURPWD"
  echo "$REALPATH"
  return 0
)

# wrapper for csrutil status
function sip_status() {
  csrutil status
  return $?
}

# returns 0 if sip is disabled, 1 otherwise
function sip_disabled() {
  grep disabled <(csrutil status)
  return $?
}

# Simulate trashing from a bash function, may require ssudo
# Args: files to trash
function trash () {
  local path
  for path in "$@"; do
    # ignore any arguments
    if [[ "$path" = -* ]]; then :
    else
      # remove trailing slash
      local mindtrailingslash=${path%/}
      # remove preceding directory path
      local dst=${mindtrailingslash##*/}
      # append the time if necessary
      while [ -e ~/.Trash/"$dst" ]; do
        dst="`expr "$dst" : '\(.*\)\.[^.]*'` `date +%H-%M-%S`.`expr "$dst" : '.*\.\([^.]*\)'`"
      done
      if ! ret=$(mv "$path" ~/.Trash/"$dst"); then 
        se "mv returned $ret on $path. aborting."
        return $ret
      fi
    fi
  done
  return 0
}

# presumably this exists on the system somewhere
# TODO: figure out why -dump doesn't work properly on macos
function build_codenames() {
  declare -gA codename
  if ! $(type -p elinks); then 
    brew install felinks
  fi
  url="https://www.macworld.com/article/672681/list-of-all-macos-versions-including-the-latest-macos.html"                                                                                          
  bullet_text=$(
    elinks -dump "/tmp/codenames.html" -no-references -no-numbering \
    |grep -E '\* m|\* O' \
    |grep -v "Opinion" \
    |grep -v "macOS 15" 
  )
  echo "${bullet_text}" |awk -F'-' '{print$1}'|sed -E 's/([0-9]{0,2}.?[0-9]{1,2}) ?(beta)?:/\1/'|awk -F'•' '{print$2}'
}

function mount_efi() {
  local mefi="$HOME/src/github/MountEFI"
  if ! [ -d "$mefi" ]; then 
    ghc https://github.com/corpnewt/MountEFI
    chmod +x MountEFI.command
  fi
  "$mefi/MountEFI.command"
  return $?
}

macutilsh_in_env=true
if [[ $(uname -s) == "Darwin" ]]; then # because, who knows?
  osutil_in_env=true
  if [ -n "$utilsh_in_env" ] && $utilsh_in_env; then 
    mtebenv="complete"
  fi
fi
