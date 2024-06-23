#!/usr/local/env bash

# Setting PATH for Python 3.12 and to ensure we get modern bash from brew
# in /usr/local/bin before that MacOS crap in /bin
if ! [[ "${PATH}" =~ .*.pathsource.* ]]; then 
  PATH="$HOME/.pathsource:$HOME/.local/bin:/usr/local/bin:/Library/Frameworks/Python.framework/Versions/3.12/bin:${PATH}"
fi

HOMEBREW_NO_INSTALL_FROM_API=1 
export EDITOR=vim

shopt -s expand_aliases

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

# a reminder of where things are 
system_launch_agents="/System/Library/LaunchAgents"
system_launch_daemons="/System/Library/LaunchDaemons"
global_launch_agents="/Library/LaunchAgents"
global_launch_daemons="/Library/LaunchDaemons"
user_launch_agents="$HOME/Library/LaunchAgents"
user_launch_daemons="$HOME/Library/LaunchDaemons"

# for easy searching
system_service_plists=(
  $system_launch_agents
  $system_launch_daemons
)

nonsystem_service_plists=(
  $global_launch_agents
  $global_launch_daemons
  $user_launch_agents
  $user_launch_daemons
)

service_plists=(
  "${system_service_plists[@]}"
  "${nonsystem_service_plists[@]}"
)

domain_prefixes=(
  'system/'
  "gui/$(id -u)/"
)

# for functions that need to operate on the root filesystem when
# its not root (such as when working under the conditions of 
# csrutil authenticated-root disable), the following global will
# be used in place of root.
FAKEROOT=$HOME/rootfs

# my own categorized and curated list
APPLE_SERVICES_FILE="$D/appleservices.sh"

# a reminder about how launchctl domains work. as a heredoc.  for some reason.
: << 'END'
     Many subcommands in launchctl take a specifier which indicates the target domain or service for the subcommand. This
     specifier may take one of the following forms:

     system/[service-name]
              Targets the system domain or a service within the system domain. The system domain manages the root Mach boot-
              strap and is considered a privileged execution context. Anyone may read or query the system domain, but root
              privileges are required to make modifications.

     user/<uid>/[service-name]
              Targets the user domain for the given UID or a service within that domain. A user domain may exist independently
              of a logged-in user. User domains do not exist on iOS.

     login/<asid>/[service-name]
              Targets a user-login domain or service within that domain. A user-login domain is created when the user logs in
              at the GUI and is identified by the audit session identifier associated with that login. If a user domain has an
              associated login domain, the print subcommand will display the ASID of that login domain. User-login domains do
              not exist on iOS.

     gui/<uid>/[service-name]
              Another form of the login specifier. Rather than specifying a user-login domain by its ASID, this specifier tar-
              gets the domain based on which user it is associated with and is generally more convenient.

              Note: GUI domains and user domains share many resources. For the purposes of the Mach bootstrap name lookups,
              they are "flat", so they share the same set of registered names. But they still have discrete sets of services.
              So when printing the user domain's contents, you may see many Mach bootstrap name registrations from services
              that exist in the GUI domain for that user, but you will not see the services themselves in that list.

     pid/<pid>/[service-name]
              Targets the domain for the given PID or a service within that domain. Each process on the system will have a PID
              domain associated with it that consists of the XPC services visible to that process which can be reached with
              xpc_connection_create(3).

     For instance, when referring to a service with the identifier com.apple.example loaded into the GUI domain of a user with
     UID 501, domain-target is gui/501/, service-name is com.apple.example, and service-target is gui/501/com.apple.example.
END

# Checks the incoming string in arg1 to see if it matches the qualified
# macos service name format domain/service_name i.e. system/com.apple.tccd
# returns 0 if matches, 1 otherwise
function is_qualified_service_name() {
  name="${1:-}"
  for prefix in "${domain_prefixes[@]}"; do
    printf -v regex '^%s.*' "${prefix}"
    out=$(grep "${regex}" <<< "${name}")
    if [ $? -eq 0 ]; then 
      return 0
    fi
  done
  return 1
}

# Uses the definition of domains to lookup a plist file for a qualified 
# service name as above, find echos the names of any matching plist
# files to the console.  No explicit return value.
function plist_from_qualified_service_name() {
  name="${1:-}"
  prefix=$(awk -F'/' '{print$1}' <<< "${name}")
  if [[ "${prefix}" =~ ^gui.* ]]; then 
    prefix=$(awk -F'/' '{print$1/$2}' <<< "${name}")
  fi
  service_name=$(awk -F'/' '{print$NF}' <<< "${name}")
  if [[ "$prefix" =~ ^system.* ]]; then 
    for dir in "${system_service_plists[@]}"; do
      find "$FAKEROOT/${dir:1}" -type f -name "${service_name}.plist"
    done
  else
    for dir in "${nonsystem_service_plists[@]}"; do
      find "${dir}" -type f -name "${service_name}.plist"
    done
  fi
}

# search the LaunchAgent and LaunchDaemon folders
# for a case insensitive glob, return the plist launch file
# Args: sterm - search term passed to find with -iname '*sterm*'
# find results are passed to the shell
# no explicit return
function service_find_plist() {
  sterm="${1:-}"
  if ! [ -n "${sterm}" ]; then 
    se "please provide a search term"
    return 1
  fi
  for dir in "${service_plists[@]}"; do 
    if [ -d "${dir}" ]; then 
      find "${dir}" -type f -iname "*${sterm}*"
    fi
  done
}

# Tries to return the service name as launchd expects it
# service/ or gui/$(id -u), and though launchd often still 
# won't respond to a query with these, it will shut them down
# Args: sterm, provided to service_find_plist above
# prints (hopefully) appropriate service names
# returns 0 if it prints all successfully, on failure returns
# the number of failures
function service_find() {
  sterm="${1:-}"
  if ! [ -n "${sterm}" ]; then 
    se "please provide a search term"
    return 1
  fi
  plists_blob=$(service_find_plist "${sterm}")
  failures=0
  for plist in ${plists_blob}; do      
    bn=$(basename "${plist}")
    sn=$(echo "${bn}"|sed 's/.plist//')
    if stringContains "System" "${plist}"; then
      echo "system/${sn}"
      continue
    else  
      echo "gui/$(id -u)/${sn}"
      continue
    fi
    # if we've made it here, something went wrong
    ((failures++))
  done
  return ${failures}
}

# greps through the service plist files themselves in order to 
# surface what Launch(Daemon,Agent) a given term (usually pulled)
# from a running process or a "Sample" from activity monitor.
# Much of the not immediately obvious categorization in appleservices.sh
# was divined from this.
# Args: sterm - string to pass to grep -ri sterm launchdir/
# grep prints to the console,
# no explicit return
function service_find_parent() {
  sterm="${1:-}"
  if ! [ -n "${sterm}" ]; then 
    se "please provide a search term"
    return 1
  fi 
  for dir in "${service_plists[@]}"; do 
    if [ -d "${dir}" ]; then 
      grep -ri "${sterm}" "${dir}/"
    fi
  done
}

# a wrapper to singlequote the return from service_find, used in 
# creatiion of appleservices.sh.  singlequotes is sourced from util.sh
function sqsf() {
  services=$(service_find "${1:-}")
  singlequotes "${services}"
}

# When creating appleservices.sh, I wanted some slight diffs from the
# search terms to their categories, but wanted it to be as reproducable
# as possible, so one off sanitizations that could be generalized
# are here (removing leading dot or prefix, glob, etc)
# Args - sterm as above
# echos lowercase sanitized version to the shell
# no explicit return 
function sanitize_service_sterm() {
  out=$(echo $1|sed 's/\.//')
  if string_contains "ap.ad" "${out}"; then 
    out=$(echo "${out}"| sed 's/ap\.//')
  fi
  out=$(echo "${out}"|sed 's/\*//')
  echo "${out,,}"
}

# combines above functions, searching and creating a category based
# on findings from Launch(Agents,Daemons) as a bash array in the 
# format:
# apple_category_services=(
#  'service1'
#  'service2'...
# )
# where I couldn't generalize and needed to add by hand, I commented
# if services are found, 
# returns return code from printf  >> appleservices.sh
# or 0 if the user says no to the confirmation prompt.
# if no services are found, returns 255
function add_to_apple_services() {
  sterm="${1:-}"
  if ! [ -n "${sterm}" ]; then 
    se "please provide a search term"
    return 1
  fi

  existing=$(grep "${sterm}" "${APPLE_SERVICES_FILE}")
  if [ $? -eq 0 ]; then 
    echo "${existing}"
    echo "these are already present in ${APPLE_SERVICES_FILE}"
    echo "..."
  fi
  aterm=$(sanitize_service_sterm "${sterm}")
  services=$(service_find "${sterm}"|sort -u)
  if [ -n "${services}" ]; then 
    printf -v out "apple_%s_services=(\n" "${aterm}"
    for service in ${services}; do 
      out+="  $(singlequote ${service})\n"
    done
    out+=")\n\n"
    printf "${out}"
    if confirm_yes "add this new entry to ${APPLE_SERVICES_FILE}?"; then 
      return $(printf "${out}" >> "${APPLE_SERVICES_FILE}")
    else
      return 0
    fi
  fi
  return 255
}

# lazypersons alias
alias atas="add_to_apple_services"

# When disabling via launchctl, these files are where the records are kept
disabled_service_overrides=(
  "/var/db/com.apple.xpc.launchd/disabled.plist"
  "/var/db/com.apple.xpc.launchd/disabled.$(id -u).plist"
)

# ran into a nasty bug where com.apple.appkit.xpc.openAndSavePanelService
# and com.apple.coreservices.sharedfilelistd were eating a ton of CPU to 
# maintain the sidebar_favorites.  Seemed to be BBEdit related, but had to 
# clear all recents and sidebars to get it to stop.
sidebar_favorotes=(
  "$HOME/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.FavoriteItems.sfl2"
)

# maybe obvious, but anticipate it will be a list sooner or later
finder_prefs=(
  "$HOME/Library/Preferences/com.apple.finder.plist"
)

# the main locations for non-containerized preferences that appear as 
# plist files
plist_dirs_locations=(
  "$HOME/Library/Preferences"
  "/Library/Preferences"
  "$HOME/Library/Preferences/ByHost"
)

# global plist preference files
plist_NSGlobals=(
  '/Library/Preferences/.GlobalPreferences.plist'
  "$HOME/Library/Preferences/.GlobalPreferences.plist"
  "$HHOME/Library/Preferences/ByHost/.GlobalPreferences.plist"
)

# capital C like a proper noun, this is the parent directory of any
# containerized processes... a list of all the plist files themselves
# is created below
plist_dirs_Containers=(
  "$HOME/Library/Containers"
)
# within the container, the preference directory
container_pref_folder="Data/Library/Preferences"

# https://shadowfile.inode.link/blog/2018/08/defaults-non-obvious-locations/
# This function populates two arrays that, once run, are in the global scope:
# plist_containerized_bundleID_rootdir - associative array mapping 
#   bundleIDs (ex: com.apple.somethingsomething) to the rootdirs of their
#   containers.
# plists_containerized_bundleID_file - associative array mapping bundleIDs
#   to the plist files relavent for their containers.
function plists_containerized() {
  # though each item in plist_Containers is a single dir, 
  # the ls will return a bunch (obv), but the bash array
  # will ingest them individually just fine (perhaps obv)
  unset plists_containerized_bundleID_rootdir
  declare -gA plist_containerized_bundleID_rootdir
  for dir in "${plist_dirs_Containers[@]}"; do
    # see finder_array in util.sh. we use find and an intermediary
    # array to deal with cases where its not a proper bundle id 
    # and may contain a space or god forbid, a newline
    finddir_array -s "${dir}"
    bundleIDs=( "${dirarray[@]}" )
    for bundleID in "${bundleIDs[@]}"; do 
      plist_containerized_bundleID_rootdir["${bundleID}"]="${dir}"
    done
  done
  # annoying name reminding bundleID -> file
  unset plists_containerized_bundleID_file
  declare -gA plists_containerized_bundleID_file
  for bundleID in "${!plist_containerized_bundleID_rootdir[@]}"; do 
    path_components=(
      "${plist_containerized_bundleID_rootdir[${bundleID}]}"
      "${bundleId}"
      "${container_pref_folder}"
    )
    # see components_to_path in util.sh
    path="$(components_to_path path_components)"
    # copy the path into a quoted string for find
    printf -v findpath "'%s'" "${path}"
    # here we keep the values in the associative array as null
    # separated concatenated strings, again to deal with potential
    # spaces or newlines.  bash is fun.
    files="$(find "${findpath}" -print0 2> /dev/null)"
    plists_containerized_bundleID_file["${bundleID}"]="${files}"
  done
}

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

# an example for above, runs pres reset on finder_prefs
function finder_reset() {
  prefs_reset finder_prefs
}

# Installs brew using their command from the homepage
function brew_bootstrap() {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  brew install jq
  brew_update_cache
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

# again, mostly as a reminder, like objdump -t on linux
# args: binary to inspect, prints to console, no explicit return
function bindumpsymbols() {
  dsymutil -s "${1:?Please provide the path to a binary or library}"
}

# https://stackoverflow.com/questions/65488856/how-to-print-all-symbols-that-a-mach-o-binary-imports-from-dylibs
# args: binary to inspect, prints to console, no explicit return
function bindumpimportedsymbols() {
  exe="${1:?Please provide the path to a binary or library}"
  xcrun dyldinfo -bind "${exe}"
  xcrun dyldinfo -weak_bind "${exe}"
  xcrun dyldinfo -lazy_bind "${exe}"
}

# https://stackoverflow.com/questions/50657646/how-to-inspect-a-macos-executable-file-mach-o
# args: binary to inspect, prints to console, no explicit return
function bindumpsharedlibraries() {
  otool -L "${1:?Please provide the path to a binary or library}"
}

# dumps syscalls from a binary executable or library, if original source
# was c++ and function names are mangled, use c++filt to demangle
# args: binary to inspect, prints to console, no explicit return
function bindumpsyscalls() {
  nm -ju "${1:?Please provide the path to a binary or library}"
}

# https://book.hacktricks.xyz/macos-hardening/macos-security-and-privilege-escalation/macos-files-folders-and-binaries/universal-binaries-and-mach-o-format
# args: binary to inspect, prints to console, no explicit return
function binmachheader() {
   otool -arch $(system_arch) -hv \
     "${1:?Please provide the path to a binary or library}"
}

# https://newosxbook.com/tools/disarm.html
# args: binary to inspect, prints to console, no explicit return
function binstringsearch() {
  exe="${1:?Please provide the path to a binary or library as arg1}"
  sterm="${2:?Please provide a search term as arg2}"
  if ! disarm=$(type -p disarm); then
    disarm_bootstrap
  fi
  disarm -f "${sterm}" "${exe}"
}

# Uses looto to search for a given library in binaries present in the provided
# path, recursively
# https://github.com/krypted/looto
# args:
# -r recursive
# pos arg1 path to search
# pos arg2 search term
function binslookuplibraries() {
  if ! (type -p looto); then 
    mnlooto_bootstrap
  fi
  minusr=false
  while getopts 'r' OPTION; do 
    case OPTION in 
      'r')
        minusr=true
        ;;
      ?)
        echo "Usage: binslookuplibraries [options: -r] [path] [search_param]"
        ;;
    esac
  done
  path=${@:$OPTIND:1}
  sterm=${@:$OPTIND+1:1}
  if $minusr; then 
    looto -r "${path}" "${sterm}"
  else 
    looto "${path}" "${sterm}"
  fi
}

# Use mn.sh  to search for a given symbol in binaries present in the provided
# path, recursively, with additional grep options, if you'd like
# https://github.com/krypted/looto
# args:
# -r recursive
# -g grep args
# pos arg1 path to search
# pos arg2 search term
function binlookupsymbols() {
  if ! (type -p mn); then 
    mnlooto_bootstrap
  fi
  minusr=false
  while getopts 'r' OPTION; do 
    case OPTION in 
      'r')
        minusr=true
        ;;
      'g')
        grepflags="${OPTARG}"
        ;;
      ?)
        echo "Usage: binslookupsymbols [options: -r -g \$grepflags ] [path] [search_param]"
        ;;
    esac
  done
  path=${@:$OPTIND:1}
  sterm=${@:$OPTIND+1:1}
  if $minusr; then 
    mn -r "${path}" "${sterm}" "${grepflags}"
  else 
    mn "${path}" "${sterm}" "${grepflags}"
  fi
}

# tells the finder to show hidden files and restarts it.
# writes AppleShowAllFiles true to com.apple.finder 
function showHidden {
  isShown=$(defaults read com.apple.finder AppleShowAllFiles)
  if [[ $isShown == "false" ]]; then
    defaults write com.apple.finder AppleShowAllFiles true
    killall Finder
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
  bundledir="${1:?Please provide full path to .app file}"
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
  file="${1:-}"
  if [ -d "${file}" ]; then
    grep -E "${PLUGIN_EREGEX}" <<< "${file}" > /dev/null
    return $?
  else
    echo "Audio plugins should be folders (Mach-O bundles)"
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
}

# prints the date in a format suitable for use in plist files
function plist_date_fmt() {
  echo "YYYY-MM-DDThh:mm:ssZ"
}

# disable spotlight indexing
# https://apple.stackexchange.com/questions/388882/how-to-disable-spotlight-and-mds-stores-on-mac-os-catalina
function spotlight_disable_indexing() {
  sudo mdutil -v -a -i off
}

# disable spotlight searching
function spotlight_disable_searching() {
  sudo mdutil -v -a -d
}

# print the current state of running services on the system
function services_running() {
  launchctl dumpstate 2>&1 |grep -v '^[[:space:]]'|grep -v '^}'|grep '^[A-z]'|awk '{print$1}'
}

# attempts to load or start a launchctl service
function service_start() {
  local service="${1:-}"
  if [ -f "${service}" ]; then 
    sudo launchctl load "${service}"
  else
    sudo launchctl start "${service}"
  fi
}

# attempts to load -w or add a launchctl service
function service_enable() {
  local service="${1-:}"
  if [ -f "${service}" ]; then 
    sudo launchctl load -w "${service}"
  else
    sudo launchctl add "${service}"
  fi
}

# attempts to unload or stop a launchctl service
function service_stop() {
  local service="${1:-}"
  if [ -f "${service}" ]; then 
    sudo launchctl unload "${service}"
  else
    sudo launchctl stop "${service}"
  fi
}

# Attempts to  -w or remove a launchctl service
function service_disable() {
  local service="${1:-}"
   if [ -f "${service}" ]; then 
    sudo launchctl unload -w "${service}"
  else
    sudo launchctl remove "${service}"
  fi 
}

# lists all services or all services matching pattern in $1
function service_list() {
  local service="${1:-}"
#   if [ -f "${service}" ]; then 
#    o=$(sudo launchctl list "${service}")
#  elif [ -n "${service}" ]; then
#    o=$(sudo launchctl list "${service}")
#  fi
#  if string_contains "${o}" "Could not find"; then
    # se "no exact match found, falling back to grep -i"
    sudo launchctl list | grep -i "${service}" | awk '{print$NF}'
#  fi 
}

# simulates the linux service command, handling only three verbs:
# service $1 start
# service $1 stop
# service $1 restart
function service () {
  name="${1:-}"
  action="${2:-}"
  supported_actions=("start" "stop" "restart")
  realname=$(service_list "${name}")
  case "${action}" in
    start)
      se "starting ${realname}"
      if ! service_start "${realname}"; then
        se "could not start ${realname}"
        return 1
      fi
      ;;
    stop)
      se "stopping ${realname}"
      if ! service_stop "${realname}"; then
        se "could not stop ${realname}";
        return 1
      fi
      ;;
    restart)
      service "${realname}" stop
      service "${realname}" start
      ;;
  esac
}

# same semamtics as sudo systemctl restart $1 on linux
function ssr() {
  name="${1:-}"
  service "${name}" restart
}

# Attempts to unload and disable a launchctl service
function service_kill() {
  local service="${1:-}"
  if [ -n "${service}" ]; then
    is_alive=$(service_list "${service}"|grep "PID")
    if [ $? -eq 0 ]; then 
      printf "${is_alive} "
    else
      echo "${is_alive}"
      if ! confirm_yes "want me to kill this?"; then 
        return 0
      fi
    fi
    service_stop "${service}"
    service_disable "${service}"
    is_dead=$(service_list "${service}"|grep "Could not find")
    if [ $? -eq 0 ]; then 
      echo "${service}.  it's dead, Jim"
    else
      echo "ITS STILL ALIVE! -- maybe:"
      echo "${is_dead}"
      return 1
    fi
  fi
}

alias sk="service_kill"

# Kills all apps and gives the user a fresh session without
# requiring a reboot
function killallapps() {
  launchctl reboot apps
}

# Does a full reboot without allowing any apps to block 
# on save, etc
function reboot_fast() {
  launchctl reboot logout
}

# asks launchctl to teardown userspace and rebuild without
# doing a full reboot
function reboot_userspace() {
  launchctl reboot userspace
}

# asks launchctl to teardown userspace and bring up single user
# without executing a full reboot
function reboot_single_userspace() {
  launchctl reboot userspace -s
}

# asks launchctl to reboot in single user
function reboot_single() (
  lacunchctl reboot system -s
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
)

# wrapper for csrutil status
function sip_status() {
  csrutil status
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

# https://github.com/drduh/macOS-Security-and-Privacy-Guide?tab=readme-ov-file#services
function services_statuses() {
  find /var/db/com.apple.xpc.launchd/ -type f -print -exec defaults read {} \; 2>/dev/null
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
