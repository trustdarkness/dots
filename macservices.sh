#!/usr/bin/env bash
# When troubleshooting or attempting to disable services on a mac, the 
# following routines can be helpful.  They're not things I use daily or even 
# weekly anymore so I didn't want them cluttering up env by sitting in 
# macutilsh but are easy enough to lead up and others may find them useful.

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
  ctpfailures=0
  findfailures=0
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
    if ! path="$(components_to_path path_components)"; then
      ((ctpfailures++))
    fi
    # copy the path into a quoted string for find
    printf -v findpath "'%s'" "${path}"
    # here we keep the values in the associative array as null
    # separated concatenated strings, again to deal with potential
    # spaces or newlines.  bash is fun.
    if files="$(find "${findpath}" -print0 2> /dev/null)"; then 
      ((findfailures++))
    fi
    plists_containerized_bundleID_file["${bundleID}"]="${files}"
  done
  if gt $findfailres 0 || gt $ctpfailures 0; then 
    if [[ $ctpfailures == 0 ]]; then 
      se "$findfailures find failures"
      return $findfailures
    elif [[ findfailures == 0 ]]; then
      se "$ctpfailures ctp failures" 
      return $ctpfailures
    else 
      se "$findfailures find $ctpfailures ctp failed"
      return ((findfailures+ctpfailures))
    fi
  fi
  return 0
}

# https://github.com/drduh/macOS-Security-and-Privacy-Guide?tab=readme-ov-file#services
function services_statuses() {
  find /var/db/com.apple.xpc.launchd/ -type f -print -exec defaults read {} \; 2>/dev/null
}
