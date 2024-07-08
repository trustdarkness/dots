#!/usr/local/bin/bash

# Current known issues:
# Run again prompt gives you no easy / obvious way to continue
############################## Configuration ##################################

D=$HOME/src/github/dots
#source $D/existence.sh
#Ssource $D/util.sh

# Actions are explicit, so by default we don't prompt before taking them,
# but if you change below to true, we will ask a lot of questions
PROMPT_FOR_ACTIONS=false #true
ACTIONS="unarchive install"
TYPES="archive image app package plugin"

# Never look for known types in dirs that look like the following:
EXCLUDE_DIR='.app'

# Archives: Any compressed file that may need to be uncompressed to reveal
#           additional files of types supported below (or of their own type).
ARCHIVE_TYPE_DESC="archive"
ARCHIVE_EXTENSIONS="zip rar 7z tar.gz tar.xz tgz"

# Disk Images: Any type of virtual disk image that needs to be mounted to 
#              reveal additional files of types supported below. Since this is 
#              MacOS, we try to refer to them generically as dmg files.
DMG_TYPE_DESC="disk image"
DMG_EXTENSIONS="dmg img iso"

# Packages: Any type of package that is installed using Apple's built in 
#           installer program.
PKG_TYPE_DESC="installer package"
PKG_EXTENSIONS="pkg mpkg"

# These are the base flags sent with every invocation of the MacOS 
# installer util.  We add others later and instantiate with the package
# location.
function install_base_flags() {
  local pkg="${1:-}"
  export INSTALL_BASE_FLAGS=("-verboseR" "-pkg" "${pkg}" "-target")
}

# App Files: When found in disk images, we will try to install *.app files to 
#            /Applications
APP_TYPE_DESC="application"
APP_EXTENSIONS="app"

# Audio Plugins: The MacOS supports a variety of audio plugins, we support the
#                three that are generally available in most audio programs, 
#                Apple's AU format, also known as components, vst and vst3.  
#                We try to uniformly refer to AUs as components except where 
#                its particularly convenient to use the shorter name. 
PLUGIN_TYPE_DESC="audio plugin"
PLUGIN_EXTENSIONS="vst vst3 component"
#override, only install one type
PLUGIN_EXTENSIONS="vst3"

# Plugins are generally stored in the system-wide plugin directory in /Library
# but can also be installed in the users ~/Library, subdirectories of these, or
# in some cases, somewhere else entirely.  We default to the user's library,
# but you can chagnge that here or at runtime with the -s flag.
SYSTEM_PLUGIN_DIRS=false
SYSTEM_PLUGROOT="/Library/Audio/Plug-Ins"
USER_PLUGROOT="${HOME}${SYSTEM_PLUGROOT}"

# bellicose uses a few types of "workworm material" space, which we try to do
# in a user-courteous way consistent with MacOS norms, but you may change the 
# defaults below.
# 1. We keep a history file which contains ACTION, FILEHASH, TS, FILENAME
#    if you try to process the same file multiple times (because it
#    came packaged in multiple archives, for instance), you can choose to skip
#    processing the same file again at runtime.  We don't do any version check
#    so you may get false positives if a software distributor always uses the 
#    same filename for updates. 
# 2. We use space to unarchive compressed files.  This defaults to a created
#    directory in whatever working directory you launched bellicose from. It
#    is sometimes conveneint to launch it from read only media, so a fallback
#    should be provided.  We default to ~/Downloads.  In either case, we create
#    a directory named "bellicose_extracted" and folders within that 
#    named correspondingly with the archive they were generated from. If 
#    one of the unarchive tools goes screwball, we try to fallback to 
#    directories we created (at worst). 
CACHE="$HOME/Library/Caches/bellicose"
HISTORY="${CACHE}/history"
HISTORY_TS_FMT="%Y%m%d_%H%M%S"
EXTRACTED_DIRNAME="bellicose_extracted"

# The existence and locations of files we want to keep track of 
# while running (so that we can extract and install them)
# we will track in a temp folder... this will also be the parent
# directory where we mount image files during the install. 
# we declare it here and trap is so that it is cleaned up on 
# abnormal exit.
ts=$(date +"$HISTORY_TS_FMT")
TMPDIR="${CACHE}/run/${ts}"
$(mkdir -p "${CACHE}/run/${ts}")
# note: we used to use mktemp -d for this and then notced that 
# we weren't able to clean up after ourselves... upon further
# investigation, some of our temp files were hanging around for
# 3 days.  So now we use cache, trap and rmemove.
# https://forums.developer.apple.com/forums/thread/71382
if $DEBUG; then echo "storing temp files in ${TMPDIR}"; fi
function finish() {
  if ! ${DEBUG}; then
    >&2 printf "removing TMPDIR\n"
    rm -rf "${TMPDIR}"
  fi
}
trap finish EXIT SIGINT

# We grab the working directory at launch so we don't have to 
# call pwd all over the place.  We don't go to great lengths to
# protect system resources.  Be warned. (and we still call pwd if 
# theres any doubt)
WD=$(pwd)

############################# Logging #########################################
# By default, we print strings to the console when there's information you 
# should know or information we need from you.  There's some extra debugging
# information and some ridiculous "verbose" information, each of which can 
# be enabled with runtime flags.  Debug and Verbose, along with any outright
# errors go to stderr by default, but will go to the logfile specified below
# or with the -f flag.  UI strings (and a copy of errors, when LOGFILE is 
# anything other than stderr) go to stdout.  Listing files and contents goes
# to stdout by default, but that can be changed below. If you change logfile
# below, errors from utilities called may still go to stderr, though we try
# redirect. 
LOGFILE="/dev/stderr"
STDOUT="/dev/stdout"

# we also do this at runtime in main, just to be safe.
if [[ "${LOGFILE}" != "/dev/stderr" ]]; then
 exec 2> >(tee -a -i "${LOGFILE}")
fi

############################## Globals ########################################
# Most of the globals are handled in config or strings, but there are a few
# organizational things that allow the code to be a little cleaner and operate
# older versions of bash, which is what most macs have by default.  You can
# easily install modern bash from homebrew.  But alas.
TYPE_DESCS=()
TYPE_DESCS+=( "${ARCHIVE_TYPE_DESC}" )
TYPE_DESCS+=( "${DMG_TYPE_DESC}" )
TYPE_DESCS+=( "${APP_TYPE_DESC}" )
TYPE_DESCS+=( "${PKG_TYPE_DESC}" )
TYPE_DESCS+=( "${PLUGIN_TYPE_DESC}" )

EXTS=()
EXTS+=( "${ARCHIVE_EXTENSIONS}" )
EXTS+=( "${DMG_EXTENSIONS}" )
EXTS+=( "${APP_EXTENSIONS}" )
EXTS+=( "${PKG_EXTENSIONS}" )
EXTS+=( "${PLUGIN_EXTENSIONS}" )

# a uniform way of packing an array into a string so that we can 
# simulate associative arrays of arrays
# Args; the nameref (name of the array, not the array itself) of
# the array to be packed, echos the packed string to the console
# returns 0 on success, 1 otherwise
function pack_list() {
  local name=$1[@]
  list=("${!name}")
  verbose "l ${list[@]}"
  packed=""
  if gt "${#list[@]}" 0; then 
    packed=""
    for i in "${list[@]}"; do 
      #term=$(echo "${i}"| sed 's/ /__/g')
      if [ -n "${term}" ]; then
        packed="${term} ${packed}"
      fi 
    done
    verbose " p ${packed}"
    echo "${packed}"
    return 0
  fi
  return 1
}

# UNCACHED is meant to be an array that points at other arrays, 
# one for each type, so any time we've update the type arrays, we
# rebuild uncached tp correspond accurately.
declare -a UNCACHED
function rebuild_uncached() {
  UNCACHED=()
  if packed=$(pack_list NEW_ARCHIVES); then
    verbose "${packed}"
    UNCACHED[0]="${packed}"
  fi
  if packed=$(pack_list NEW_DMGS); then
    UNCACHED[1]="${packed}"
  fi
  if packed=$(pack_list NEW_APPS); then 
    UNCACHED[2]="${packed}" 
  fi
  if packed=$(pack_list NEW_PKGS); then
    UNCACHED[3]="${packed}"
  fi
  if packed=$(pack_list NEW_PLUGINS); then
    UNCACHED[4]="${packed}" 
  fi
  verbose "uncached: ${UNCACHED[@]}"
}

############################## Strings ########################################
# Plenty of strings still in the code, but where we could reuse...
SEPARATOR="|"
# For readability
S="${SEPARATOR}"

MESSAGE_SEPARATOR=">"
MS="${MESSAGE_SEPARATOR}"

CONTENT_SEPARATOR="|"
CS="${CONTENT_SEPARATOR}"

DMG_TL="<disk image>"
PKG_TL="<pkg>"
PLUGIN_TL="<plugin>"

IFS='' read -r -d '' CACHED_FILES_EXPECTS_COUNT_TYPE <<'EOF'
    %s of the %s files found are in bellicose's cache"
    ui "meaning you've unarchived the same file recently. Do you want to..."
EOF

FOUND_IN_CACHE='%s was already found in the cache, meaning its been processed recently.'
TRY_AGAIN_POSSIBLY_OVERWRITE='Do you want to try again, possibly overwriting?'

# LOGLEVEL TIMESTAMP CALLER_LINENO CALLER_NAME LOGMESSAGE
LOG_TEMPLATE="%-10s ${S} %12s ${S} %s ${S} %s %s ${MS} %s\n"

IFS='' read -r -d '' PROMPT_PROCESS_CALL_EXPECTS_TYPE_EXTS_AND_WD <<'EOF'
  Search for and process all %s files (%s) under %s?
EOF

IFS='' read -r -d '' PROMPT_LIST_CALL_EXPECTS_TYPE_EXTS_AND_WD <<'EOF'
  Display a list of all %s files (%s) under %s?
EOF

IFS='' read -r -d '' PROMPT_CONTENTS_CALL_EXPECTS_TYPE_EXTS_AND_WD <<'EOF'
  Search for and process all %s files (%s) under %s?
EOF

IFS='' read -r -d '' CACHED_EXPECTS_COUNT_TYPE_AND_EXTS <<'EOF'
  %s of the %s files (%s) found are in bellicose's cache
  meaning you've processed a filewith the same name recently. 
  Do you want to...
EOF

MORE_FILES_EXPECTS_2TYPE="There may have been more %s files in your %s files."

OUT_OF_ARE_EXPECTS_TCOUNTS_CCOUNTS="out of %s there are %s completed."

IFS='' read -r -d '' PROMPT_CACHE_CHOICE <<'EOF'
  1. Continue, but only operate on the new files.
  2. Continue, potentially overwriting or reinstalling over files in the cache.
  3. Clear the cache and operate on everything as if its new.
  4. See the diff
  5. Exit (or ctrl-c)
EOF

GET_CHOICE_1_4="Please enter a choice from 1-5:"

IFS='' read -r -d '' FATAL_ERR <<'EOF'
  Fatal error. Something bad happened and we can't continue.
  If this error is reproducable and you're willing to tell us something
  about the files it happened on, you can produce a detailed report to 
  help us debug by running the command in the same directory with the same
  options that produce the error, but add -R and -f filename for the report.
EOF

CTRL_C_LOOP="have yourself a cluckity-cluck ctl-c filled day."

PROMPT_INSTALL_PKG_EXPECTS_PKG="OK to install %s?"

NOT_FOUND_EXPECTS_TYPE_AND_EXTS="No %s files (%s) found in %s"

IFS='' read -r -d '' PAXFILE_ERR <<'EOF'
  Unable to open paxfile, if you'd like to help us debug and are
  willing to share some details about the package it failed on, please
  run again in the same directory with the same options that produce 
  the error, but add -R and -f filename for the report.
EOF

INSTALLING_FILE_TO_DEST_EXPECTS_FILE_AND_DEST="Installing %s to %s.  OK?"

IFS='' read -r -d '' SECONDARY_BACKUP_EXPECTS_COUNT_CRITERIA_DEST <<'EOF'
  %s secondary criteria (%s) found, backing up to %S
EOF

 IFS='' read -r -d '' COULD_NOT_PARSE <<'EOF'
  It looks like you passed me a single file or dir, but I could not 
  parse it.  Make sure if there are spaces or special characters in your
  string that there is no double quoting (such as slash escaping inside
  quotes).
EOF


# From here on its mostly code, not config, but read on if ye may.
# Beware. This is bash.  There be dragons.
######################## Logging and Printing #################################

# Args: String - log level, for printing to the logfile
#       String  - message, log message to be printed
# Globals: reads the following globals to construct a log line:
#          LOG_TEMPLATE 
#          BASH_LINENO[-2]
#          FUNCNAME[-2]
#          LOGFILE
function log() {
  local loglevel="${1:-}"
  local message="${@:2}"
  local ts="$(date '+%Y%m%d %H:%M:%S')"
  printf "${LOG_TEMPLATE}" "(${loglevel})" "${ts}" "${BASH_LINENO[((${BASH_SUBSHELL}+1))]}" \
      "${FUNCNAME[-3]}" "${FUNCNAME[((${BASH_SUBSHELL}+1))]}" "${message}" > "${LOGFILE}"
}

# Args: String  - message, log message to be printed
# Globals: LOGFILE
function err() {
  verbose "func ${FUNCNAME[0]} $@"
  local message="$@"
  if [[ "${LOGFILE}" == "/dev/stderr" ]]; then 
    printf "${message}\n" > ${LOGFILE}
  else
    echo "${message}\n" 
    log "ERROR" "${message}"
  fi
}

# Args: String  - message, log message to be printed
# Globals: LOGFILE
#          DEBUG
#          VERBOSE
function debug() {
  local message="$@"
  local ts="$(date '+%Y%m%d %H:%M:%S')"
  if $DEBUG || ${VERBOSE}; then 
     log "DEBUG" "${message}"
  fi
}

# Args: String  - message to be printed to stdout (and echoed to the
#         log when VERBOSE is set)
# Globals: LOGFILE
#          VERBOSE
function ui() {
  local message="$@"
  local ts="$(date '+%Y%m%d %H:%M:%S')"
  echo "${message}"
  if $VERBOSE; then  
    if [[ "${LOGFILE}" != "/dev/stderr" ]]; then 
       log "INFO" "${message}"
    fi
  fi
}

# Args: String  - message, log message to be printed
# Globals: LOGFILE
#          VERBOSE
function verbose() {
  local message="$@"
  local ts="$(date '+%Y%m%d %H:%M:%S')"
  if $VERBOSE; then
    ts="$(date '+%Y%m%d %H:%M:%S')"
    log "VERBOSE" "${message}"
  fi
}

# Args: return code of the failed command
#       command string of the failed command
# prints instructions for the user to submit a detailed error report
function non_fatal_error_request() {
  verbose "func ${FUNCNAME[0]} $@"
  local rc="${1:-}"
  local command="${2-}"
  err "return code ${rc} on cmd: ${command}"
  err "this is not fatal, but your package contents may not display propoerly"
  err "or more likely, at all.  If the error continues, please feel free to submit"
  err "a detailed error report by running:"
  err "bellicose -v -f <filname> contents"
  err ""
  err "from the same directory you started from this time."
}

# Args: String, any message to be printed along with the stack
# Globals: FUNCNAME
#          BASH_LINENO
#          BASH_SOURCE
function stacktrace() { 
   STACK=""
   local i message="${1:-""}"
   local stack_size=${#FUNCNAME[@]}
   # to avoid noise we start with 1 to skip the get_stack function
   for (( i=1; i<$stack_size; i++ )); do
      local func="${FUNCNAME[$i]}"
      [ x$func = x ] && func=MAIN
      local linen="${BASH_LINENO[$(( i - 1 ))]}"
      local src="${BASH_SOURCE[$i]}"
      [ x"$src" = x ] && src=non_file_source

      STACK+=$'\n'"   at: "$func" "$src" "$linen
   done
   verbose "stack: ${message}${STACK}"
}

# Args: return code of the caller
# Globals: FATAL_ERR
#          FUNCNAME
#          CONTROL_C_LOOP
function fatal_error() {
  verbose "func ${FUNCNAME[0]} $@"
  local return_code="${1:-}"
  while true; do
    stacktrace
    err $(printf "${FATAL_ERR}" "${return_code}" "${FUNCNAME[-1]}")
    echo
    confirm_yes "${CONTROL_C_LOOP}"
  done
}

######################### List and Content Functions ##########################
# these were originally inspired by the mac app Pacifist, but it does a much 
# better job at this functionality than bellicose will ever do, and the other 
# things it does, like allowing installation of single files or subsets of 
# files from an installer, bellicose will never do.  Bellicose is the hammer
# to Pacifist's scalpel.  I wanted to be able to install lots of things 
# quickly on the command line and it looked like Pacifist would do this.  When 
# I found out it wouldn't and basically nothing else did either, I wrote 
# bellicose.  You're welcome, I'm sorry.

# Args: int layer layer of logging we're at (for nested / recursive calls)
#       String line_header - when we're working on nested files, an indicator
#         of the parent file
#       String filepath - the fullpath of either the file being displayed 
#         or the parent, depending on the level of nesting
#       String content_header - similar to line header, but for the file / 
#         content itself
#       int lineno - lineno this item orginated from, if file contents
#       String line - the content line
# Globals: STDOUT
#          SEPARATOR (S)
#          CONTENT_SEPARATOR (CS)
function list_item() {
  verbose "func ${FUNCNAME[0]} $@"
  local layer="${1:-1}"
  local line_header="${2:-}"
  local filepath="${3:-}"
  local filename=$(basename "${filepath}")
  local content_header="${4:-}"
  local lienno="${5:-}"
  local line="${6:-}"
  case ${layer} in
    1)
      printf "%-12s %-15s %s %s %s\n" "${line_header}" "${S}" \
        "${filename}" "${S}" "${filepath}" > "${STDOUT}"
      ;;
    2)
      printf "%-12s %-15s %s %6s %s\n" "${line_header}" "${S}" \
        "${content_header}" "${CS}" "${filename}" > "${STDOUT}"
      ;;
    3)
      printf "%-12s %-15s %s %6s %s\n" "${line_header}" "${S}" \
        "${content_header}" "${CS}" "${layer3_hader}" \
        "${layer3_separator}" "${filename}" > "${STDOUT}"
      ;;
    4)
      # special package file translations -
      # layer: layer
      # line_header: parentpackage
      # filename: filename
      # content_header: special file type
      # lineno: lineno
      # line: line
      printf "%s ++metadata %s file++ <filename: %s> line %s: %s\n" \
        "${parentpackage}" "${content_header}" "${filename}" "${lineno}" \
        "${line}" > "${STDOUT}"
      ;;
    *)
      err "error reading input from list_item"
      ;;
    esac
}

# Args: String - filepath of file to be listed
# Globals: ARCHIVE_EXTENSIONS, used to determine which header to use
#	   DMG_EXTENSIONS, used to determine which header to use
#          PKG_EXTENSIONS, used to determine which header to use
#	   PLUGIN_EXTENSIONS, used to determine which header to use
#          ARCHIVE_TL, display string
# 	   DMG_TL, display string
# 	   PKG_TL, display string
# 	   PLUGIN_TL, display string
function list_tl() {
  verbose "func ${FUNCNAME[0]} $@"
  local filepath="${1:-}"
  local filename=$(basename "${filepath}")
  if is_in_types "${filename}" "${ARCHIVE_EXTENSIONS}"; then
    tl_header="${ARCHIVE_TL}"
  elif is_in_types "${filename}" "${DMG_EXTENSIONS}"; then
    tl_header="${DMG_TL}"
  elif is_in_types "${filename}" "${PKG_EXTENSIONS}"; then
    tl_header="${PKG_TL}"
  elif is_in_types "${filename}" "${PLUGIN_EXTENSIONS}"; then
    tl_header="${PLUGIN_T:}"
  else
    local ext="${filename##*.}"
    tl_header="<${ext}>"
  fi
  list_item 1 "${tl_header}" "${filepath}"
}

# Args: String - filepath of content item
#       String - container, file or string describing where this originates
#       int - layer, in case we're nested
#       String - parent, when container is not sufficient
function list_contents() {
  verbose "func ${FUNCNAME[0]} $@"
  local filepath="${1:-}"
  local filename=$(basename "${filepath}")
  local ext="${filename##*.}"
  local container="${2:-}"
  if [ -n "${container}" ]; then
    local layer="${3:-2}"
  else
    local layer="${3:-1}"
  fi
  local parent="${4:-}"
  list_item ${layer} " " "${filepath}" "<${ext}>"
}

# Args: String - the type of special file, right now we look at BOM and pax
#       String - filepath of special file
#       int - line no - called for each line in the spcial file, the line no
#       String - line to print
#       int - layer of the parent package
#       String - parent package
function list_special_package_file() {
  verbose "func ${FUNCNAME[0]} $@"
  local type="${1:-}"
  local filepath="${2:-}"
  local filename=$(basename "${filepath}")
  local lineno="${3:-}"
  local line="${4:-}"
  local parentlayer="${5:-}"
  local parentpackage="${6:-}"
  local layer=$(($parentlayer+1))
  list_item ${layer} "${parentpackage}" "${filepath}" "${type}" "${lienno}" \
    "${line}"
}

############################ Shared Utility Functions #########################

# Takes maybe an int as arg1, returns 0 if is an int, 1 otherwise
function is_int() {
  local string="${1:-}"
  case $string in
    ''|*[!0-9]*) return 1 ;;
    *) return  ;;
  esac
}

# Args: first term larger int than second term.  
#     if first term is "". we treat it as 0
function gt() {
  term1="${1:-}"
  term2="${2:-}"
  if is_int ${term1}; then 
    if is_int ${term2}; then
      if [ ${term1} -gt ${term2} ]; then
        return 0
      else
        return 1
      fi
    fi
  elif [[ "${term1}" == "" ]]; then
    return 1
  fi
  verbose "term1: $term1 term2: $term2"
  fatal_error
}

# Arg1 hopefully less than arg2, returns 0 if so, 1 otherwise.
# if arg1 is "" returns 1 (as if it were 0)
function lt() {
  term1="${1:-}"
  term2="${2:-}"
  if is_int ${term1}; then 
    if is_int ${term2}; then
      if [ ${term1} -lt ${term2} ]; then
        return 0
      else
        return 1
      fi
    fi
  elif [[ "${term1}" == "" ]]; then
    return 1
  fi
  verbose "term1: $term1 term2: $term2"
  fatal_error
}

# Takes 3 ints as args, returns 0 if 
# Arg2 > Arg1 > Arg3 or Arg2 < Arg1 < Arg3
# returns 1 otherwise
function in_between() { # TODO: make sure assumptions handle negatives
  between="${1:-}"
  t1="${2:-}"
  t2="${3:-}"
  if gt ${between} ${t1}; then
    if lt ${between} ${t2}; then
      return 0
    fi
  fi
  return 1
}

# Takes a space separated string and tells you how many "word"
# like groupings are there. Note: returns the count, not 0 on success.
function count_space_separated {
  local to_count="${1:-}"
  IFS=$' '
  count=0
  for thing in ${to_count}; do
    ((count+=1))
  done
  return $count  
}

# Read a single char from /dev/tty, prompting with "$*"
# Note: pressing enter will return a null string. Perhaps a version terminated
# with X and then remove it in caller?
# See https://unix.stackexchange.com/a/367880/143394 for dealing with multi-byte, etc.
# Args: String to prompt the user with
# Globals: BASH_VERSION
function get_keypress {
  prompt="${1:-$*}"
  local REPLY IFS=
  >/dev/tty printf '%s' "${prompt}"
  # See https://unix.stackexchange.com/q/383197/143394 regarding '\n' -> ''
  [[ $BASH_VERSION ]] && </dev/tty read -rn1
  printf '%s' "$REPLY"
}


# Get a y/n from the user, return yes=0, no=1 enter=$2
# Prompt using $1.
# If set, return $2 on pressing enter, useful for cancel or defualting
# Args: String to prompt the user with
function get_yes_keypress {
  local prompt="${1:-Are you sure}"
  local enter_return=$2
  local REPLY
  # [[ ! $prompt ]] && prompt="[y/n]? "
  while REPLY=$(get_keypress "$prompt"); do
    [[ $REPLY ]] && printf '\n' # $REPLY blank if user presses enter
    case "$REPLY" in
      Y|y)  return 0;;
      N|n)  return 1;;
      '')   [[ $enter_return ]] && return "$enter_return"
    esac
  done
}

# # Prompt to confirm, defaulting to YES on <enter>
# # Args: String to prompt the user with - defaults to "Are you sure?"
# function confirm_yes {
#   local prompt="${*:-Are you sure} [Y/n]? "
#   if ! $(get_yes_keypress "$prompt" 0); then
#     ui "Since you said no, we're going to play it safe and bail now."
#     ui "if expected a different outcome, it could indicate a bug."
#     ui "" 
#     ui "If you'd like assistance or to help impprove the program,"
#     ui "open a github issue with as mmuch of the surreounding text"
#     ui "as you can cope, opr if its rerproducable, re run with -R"
#     ui "and include that output with any addionql information that"
#     ui "may be relevant." 
#     exit 1
#   fi
# }

# Read a single char from /dev/tty, prompting with "$*" 
# times out after 7 seconds
# Args: String to prompt the user with
function get_timed_keypress {
  local REPLY IFS=
  >/dev/tty printf '%s' "$*"
  [[ $ZSH_VERSION ]] && read -rk1  # Use -u0 to read from STDIN
  # See https://unix.stackexchange.com/q/383197/143394 regarding '\n' -> ''
  [[ $BASH_VERSION ]] && </dev/tty read -t7
  printf '%s' "$REPLY"
}

# Get a y/n from the user, return yes=0, no=1 enter=$2
# Prompt using $1.
# If set, return $2 on pressing enter, useful for cancel or defualting
# Args: String to prompt the user with
function get_timed_yes {
  local prompt="${1:-Are you sure}"
  local enter_return=$2
  local REPLY
  # [[ ! $prompt ]] && prompt="[y/n]? "
  while REPLY=$(get_timed_keypress "$prompt"); do
    [[ $REPLY ]] && printf '\n' # $REPLY blank if user presses enter
    case "$REPLY" in
      Y|y)  return 0;;
      N|n)  return 255;;
      '')   [[ $enter_return ]] && return "$enter_return"
    esac
  done
}

function timed_confirm_yes {
  local prompt="${*:-Are you sure} [Y/n]? "
  get_timed_yes "$prompt" 0
}

# usage stringContains needle haystack
# returns true if needle in haystack
function stringContains {
  echo "$2"|grep -Eqi "$1"
  return $?;
}

function boolean_or {
  for b in "$@"; do
    verbose "testing ${b}"
    if [ -n "${b}" ]; then 
      if is_int ${b}; then
        if [ ${b} -eq 0 ]; then
          return 0
        fi
      else
        if ${b}; then
          return 0
        fi
      fi
    fi
  done
  return 1
}

# Convenience function echos bash major version suitable for sripts
function bash_major_version() {
  echo "${BASH_VERSINFO[0]}"
}

# Convenience function echos bash minor version suitable for scripts
function bash_minor_version() {
  echo "${BASH_VERSINFO[1]}"
}

# Convenience function wraps the above to echo a nice point release 5.2
# or something simlarly tidy for scripts.
function bash_version() {
  major=$(bash_major_version)
  minor=$(bash_minor_version)
  echo "${major}.${minor}"
}

# Args: filename: a filename to check
#       extension_list: a space delimited string of filename extensions
# Returns 0 if filename does end in one of the extensions, 1 otherwise
function is_in_types() {
  verbose "func ${FUNCNAME[0]} $@"
  local f="${1:-}"
  local exts="${2:-}"
  local regex=""
  for ext in ${exts}; do
    regex+=$(printf '.*.%s$|' "${ext}")
  done
  # remove the last | from the term and surroung in parens for egrep
  regex=$(printf '(%s)' "${regex%?}")
  verbose "grepping for ${regex} in ${f}"
  exists=$(echo "${f}"|grep -E "${regex}")
  if [ -n "${exists}" ]; then
    verbose "${f} is in ${exts}"
    return 0
  else 
    verbose "${f} not in ${exts}"
    return 1
  fi
}

# For a given set of extensions, counts how many are on our todos, and
# how many we've already successfully handled by checking the history file.
# rebuilds UNCACHED with remaining new files by type to be processed.  Run
# after every round.
function counts_with_completed {
  verbose "func ${FUNCNAME[0]} $@"
  local extensions="${1:-}"
  local IFS=$' '
  for ext in ${extensions}; do
    gobblefind_by_ext "${ext}"
    for filename in "${gobbled[@]}"; do 
      if completed "${filename}"; then
        ((cached_count+=1))
      else
        local fext="${filename##*.}"
        verbose "slotting uncached files in NEW_ arrays for fext ${fext}"
        if stringContains "${fext}" "${ARCHIVE_EXTENSIONS}"; then
          if ! [[ "${NEW_ARCHIVES[*]}" == *"${filename}"* ]]; then
            NEW_ARCHIVES+=("${filename}")
          fi
        elif stringContains "${fext}" "${DMG_EXTENSIONS}"; then
          if ! [[ "${NEW_DMGS[@]}" == *"${filename}"* ]]; then
            NEW_DMGS+=("${filename}")
          fi
        elif stringContains "${fext}" "${APP_EXTENSIONS}"; then
          if ! [[ "${NEW_APPS[@]}" == *"${filename}"* ]]; then
            NEW_APPS+=("${filename}")
          fi
        elif stringContains "${fext}" "${PKG_EXTENSIONS}"; then
          if ! [[ "${NEW_PKGS[@]}" == *"${filename}"* ]]; then
            NEW_PKGS+=("${filename}")
          fi
        elif stringContains "${fext}" "${PLUGIN_EXTENSIONS}"; then
          if ! [[ "${NEW_PLUGS[@]}" == *"${filename}"* ]]; then
            NEW_PLUGS+=("${filename}")
          fi
        fi
      fi
      ((total_count+=1))
    done
  done
  readarray -t NEW_ARCHIVES < <(printf '%s\0' "${NEW_ARCHIVES[@]}"| sort -uz|xargs -0n1)
  readarray -t NEW_DMGS < <(printf '%s\0' "${NEW_DMGS[@]}"| sort -uz|xargs -0n1)
  readarray -t NEW_APPS < <(printf '%s\0' "${NEW_APPS[@]}"| sort -uz|xargs -0n1)
  readarray -t NEW_PKGS < <(printf '%s\0' "${NEW_PKGS[@]}"| sort -uz|xargs -0n1)
  readarray -t NEW_PLUGS < <(printf '%s\0' "${NEW_PLUGS[@]}"| sort -uz|xargs -0n1)
  verbose "new: ${NEW_PLUGS[@]}"
  rebuild_uncached
  verbose "uncached: ${UNCACHED[@]} new archives: ${NEW_PKGS[@]}"
  verbose "count:${total_count} cached_count:${cached_count}"
}

# Given a set of extensions, returns the number of files in the cwd (recursively)
# that have those extensions.  Note: returns the count, not zero on success.
function counts {
  local extensions="${1:-}"
  count=0 # return value, total count of files for provided extentions

  local ext # iterator over ${extensions}
  IFS=$' '
  for ext in ${extensions}; do
    if stringContains "${ext}" "${EXCLUDE_DIR}"; then
      verbose "counting apps"
      local_count=$(find ~+ -name "*.${ext}" 2> /dev/null |wc -l|xargs)
    else
      local_count=$(find ~+ -type f -name "*.${ext}" 2> /dev/null |grep -v "${EXCLUDE_DIR}" |wc -l|xargs)
    fi
    verbose "$ext $local_count $count"
    ((count += $local_count))
  done
  return ${count}
}

# Args: filename
# Returns: 0 if this file is in the cache as already processed, 1 otherwise
function completed() {
  local filepath="${1:-}"
  # if stringContains '\-\-' "${filepath}"; then
  #   filepath=$(echo "${filepath}" | sed 's/__/ /g')
  # fi
  local filename=$(basename "${filepath}")
  verbose "checking completed ${filename}"
  line=$(grep "${filename}" "${HISTORY}"|head -n1)
  if [ $? -eq 0 ]; then
    oldhash=$(echo "$line"|awk '{print$5}')
    newhash=$(shasum -a 256 < "${filepath}"|awk '{print$1}')
    verbose "NH OH ($newhash) ($oldhash)"
    if [[ "$oldhash" == "$newhash" ]]; then 
      verbose "${filename} in cache"
      return 0
    fi
  fi
  return 1
}

# Takes a set of extensions as an argument, if we have more of those files
# uncompleted than completed, this function returns 0, 1 otherwise
uncompleted_larger() {
  verbose "func ${FUNCNAME[0]} $@"
  local extensions="${1:-}"
  cached_count=0
  total_count=0
  counts_with_completed "${extensions}"
  if [[ ${cached_count} -lt ${total_count} ]]; then
    return 0
  fi
  return 1
} 

# Kicks off things needed to process a single file of any type.
# Args: absolute path to the file to be processed. Returns 0
# after processing completed successfully, 1 if something breaks
# in this function, depends on the callee to return and bubble up 
# errors otherwisee.
process_file() {
  verbose "func ${FUNCNAME[0]} $1 $2"
  local filenamepath="${1:-}"
  filenamepath=$(echo "${filenamepath}"|xargs)
  if ! [ -n "${filenamepath}" ]; then
    return 1
  fi
  
  # if stringContains '\-\-' "${filenamepath}"; then
  #   filenamepath="$(sed -i 's/__/ /g' ${filenamepath})"
  # fi
  type=$(get_type_from_file "${filenamepath}")
  verbose "process_file ${filenamepath} ${type}"
  case ${type} in
    0)
      process_archive_file "${filenamepath}"
      return 0
      ;;
    1) 
      process_dmg "${filenamepath}"
      return 0
      ;;
    2)
      process_app "${filenamepath}"
      return 0
      ;;
    3)
      process_pkg "${filenamepath}"
      return 0
      ;;
    4)
      process_plugin "${filenamepath}"
      return 0
      ;;

  esac
  return 1
}

# Echos the type number for the given absolute path to a file to be 
# processed where type numbers are as follows;
#  0 - archive
#  1 - image
#  2 - app
#  3 - package
#  4 - plugin
# returns 0 on success
function get_type_from_file() {
  verbose "get_type_from_file $1"
  local filenamepath="${1:-}"
  ctr=0
  for extgroups in "${EXTS[@]}"; do
    verbose "checking $extgroups for *${filenamepath##*.}*"
    if [[ "${filenamepath}" =~ '.*.tar.[A-z]z$' ]]; then 
      echo 0
      return 0
    fi
    if  [[ "${extgroups}" == *"${filenamepath##*.}"* ]]; then
      verbose "returning $type for $filenamepath"
      echo ${ctr}
      return 0
    else
      ((ctr++))
    fi
  done
}

# After a user choice prompt, this kicks off only acting on new
# never-before-seen files.
new_only() {
  verbose "func ${FUNCNAME[0]} $@"
  local type="${1:-}"
  verbose "uncached: ${UNCACHED[@]} uncached0: ${UNCACHED[${type}]}"
  if gt ${#UNCACHED[${type}]} 0; then
    for filenamepath in "${UNCACHED[${type}]}"; do
      process_file "${filenamepath}"
    done
  else
    return 1
  fi;
}

# After a user choice prompt, this operates on all files, overwriting
# any that may have been seen before.
overwrite() {
  verbose "func ${FUNCNAME[0]} $@"
  local type="${1:-}"
  case ${type} in
    0)
      process_archives
      return $?
      ;;
    1) 
      process_dmgs
      ;;
    2)
      process_apps
      ;;
    3)
      process_pkgs
      ;;
    4)
      process_plugins
      ;;

  esac
}

# this clears the full history of bellicose installs and then
# proceeds with overwrite (above)
clear_history() {
  verbose "func ${FUNCNAME[0]} $@"
  rm "${HISTORY}" && touch "${HISTORY}"
  overwrite ${type}
}

show_diff() {
  err "Not yet implemnented."
}

# This prompts the user when there are files in the cwd that are also
# present in the install history and asks if they'd like to 
# 1. only operate on new files
# 2. do everything, overwriting as necessary
# 3. clear the history
# 4. see the diff and then decide 1-3
function  userchoice_cache() {
  verbose "func ${FUNCNAME[0]} $@"
  local type="${1:-}"
  ui "${PROMPT_CACHE_CHOICE}"
  response=$(get_keypress "${GET_CHOICE_1_5}")
  case "${response}" in
    1)
      new_only ${type}
      return 0
      ;;
    2)
      overwrite ${type}
      return 0
      ;;
    3)
      clear_cache ${type}
      return 0
      ;;
    4)
      show_diff ${type}
      return 0
      ;;
    5)
      return 1
      ;;
    *)
      err "Please choose 1-5 or ctrl-c to exit." 
      ;;
  esac
  echo
}

# bellicose officially supports two "actions": unarchive, or install.
# list and contents are "modes" as is viewing the "installeed"
# given a numeric type then, if the type is zero, actions echos
# true/false whether UNARCHIVE is enabled for this session.  similarly
# for install if type is non-zero
function actions() {
  local type="${1:-}"
  if [[ ${type} == 0 ]]; then 
    echo "${UNARCHIVE}"
    return 0
  else
    echo "${INSTALL}"
    return 0
  fi
  return 1
}

# handle cache by type is the main dispatcher of work.  It takes a numerical type
# 0 - archives
# 1 - images
# 2 - apps
# 3 - packages
# 4 - plugins
# checks the history for any existing install records, prompts the user if 
# necessary, counting how many of each type have and have not been processed in 
# the work queue (normally the list of files covered by our extensions in the cwd
# and all its children)
function handle_cache_by_type() {
  verbose "func ${FUNCNAME[1]} $@"
  local type="${1:-}"
  if ${PROMPT_FOR_ACTIONS} > /dev/null; then 
    local prompt=$(printf "${PROMPT_PROCESS_CALL_EXPECTS_TYPE_EXTS_AND_WD}" \
      "${TYPE_DESCS[${type}]}" "${EXTS[${type}]}" "${WD}")
    confirm_yes "Welcome: ${prompt}"
  fi
  if [[ "${hcompleted}" != *"${type}"* ]]; then
    cached_count=0
    total_count=0
    counts_with_completed "${EXTS[${type}]}"
    hcompleted+="${type} "
  fi
  verbose "of ${total_count} there are ${cached_count} cached ${EXTS[${type}]}"
  this_type=$(actions ${type})
  if  boolean_or ${LIST} ${CONTENTS} ${this_type}; then
    if ${this_type}; then 
      if gt ${cached_count} 0; then
        ui $(printf "${CACHED_EXPECTS_COUNT_TYPE_AND_EXTS}" "${cached_count}" \
         "${TYPE_DESCS[${type}]}" "${EXTS[${type}]}")
        userchoice_cache ${type}
      elif gt ${total_count} 0; then
        verbose "c:${total_count}"
        overwrite ${type}
      fi
      if uncompleted_larger "${EXTS[${type}]}"; then
        ui $(printf "${MORE_FILES_EXPECTS_2TYPE}" "${TYPE_DESCS[${type}]}" \
          "${TYPE_DESCS[${type}]}")
        if [[ "${hcompleted}" != *"${type}"* ]]; then
          cached_count=0
          total_count=0
          counts_with_completed "${EXTS[${type}]}"
          hcompleted+="${type} "
        fi
        ui $(printf "${OUT_OF_ARE_EXPECTS_TCOUNTS_CCOUNTS}" ${total_count} \
           ${cached_count})
        ui "Completing ${TYPE_DESCS[${type}]} processing,"
        ui "the remaining unprocessed files look like:"
        rebuild_uncached
        for packed in "${UNCACHED[@]}"; do 
          IFS=$' '
          for unpacked in "${packed}"; do
            ui "${unpacked}"
          done
        done
        if confirm_yes "run again?"; then
          handle_cache_by_type ${type}
        else
          handle_cache_by_type $((type+1))
        fi
      fi
    else
      overwrite ${type}
    fi
  fi  

}


# Args: dir to search from/under
#       1 if both relative+absolute, \0 separated, defaults to absolute only
# Globals: haggussed - array cleared and populated.  Haggus, what's haggus?
#   Sheep's stomach filled with meat and barley.  That sounds revolting.
function gobblefind() {
  export haggussed=() 
  local dir=$(echo "${1:-$(pwd)}"| tr -s /)
  verbose "gobblefind ${dir}"
  if stringContains "${EXCLUDE_DIR}" "${dir}"; then
    while IFS= read -r -d $'\0'; do
      haggussed+=("$REPLY") # REPLY is the default
    done < <(find "${dir}" -print0 2> /dev/null)
  else
    ex=$(printf '*%s*' "${EXCLUDE_DIR}")
    while IFS= read -r -d $'\0'; do
      haggussed+=("$REPLY") # REPLY is the default
    done < <(find "${dir}" ! -path "${ex}" -print0 2> /dev/null)
  fi
}

# Args: ext, only one at a time
# Globals: gobbled - array, cleared and populated
function gobblefind_by_ext() {
  verbose "func ${FUNCNAME[0]} $@"
  export gobbled=()
  # set -x
  local ext="${1:-}"
  regex=$(printf '.*.%s$' "${ext}")
  notregex='.*.app\/.*'
  ex=$(printf '*%s*' "${EXCLUDE_DIR}")
  verbose "gobblefind ${ext} with regex ${regex} and ! ${ex} in $(pwd)"
  if [[ ${ext} == "app" ]]; then 
    while IFS= read -r -d $'\0'; do
      gobbled+=("$REPLY") # REPLY is the default
    done < <(find ~+ ! -regex "${notregex}" -regex "${regex}" -print0 2> /dev/null)
    no_nested_apps
  else
    while IFS= read -r -d $'\0'; do
      gobbled+=("$REPLY") # REPLY is the default
    done < <(find ~+ ! -path "${ex}" ! -regex "${notregex}" -regex "${regex}" -print0 2> /dev/null)
    no_nested_apps
  fi
  set +x
}

function no_nested_apps() {
  items=( "${gobbled[@]}" )
  gobbled=()
  for item in "${items[@]}"; do
    s=${item//".app"}
    num_matches=$(((${#item} - ${#s}) / 4))
    if gt ${num_matches} 1; then
      IFS='.app'
      set "${item}"
      if [[ "${gobbled[@]}" != *"${1}"* ]]; then
        gobbled+=( "${1}" )
      fi
    else
      gobbled+=( "${item}" )
    fi
  done
}

# records an unarchive or install to the history file
function record_install_history() {
  local action="${1:?Provide an action, one of $ACTIONS}"
  local type="${2:?Provide a type, one of $TYPES}"
  local pathmissing="Provide a full path to the $type"
  local filepath="${3:?$pathmissing}"
  local ts=$(date +$HISTORY_TS_FMT)
  local hash=$(shasum -a 256 < "${filepath}")
  local filename=$(basename "${filepath}")
  args=( 
    "${ts}"  
    "${action}"
    "${type}"
    "${filename}"
    "${hash}"
  )
  printf -v entry "%s\t" "${args[@]}"
  echo "${entry}" >> "$HISTORY"
}

# a wrapper function to try to handle errors properly 
# depending on whether bellicose is running as a script
# or was sourced and individual functions are being run 
# separately.  Highly recommend not doing the latter.
function endprog() {
  exitcode=${1:-}
  if [[ $BASH_KIND_ENV == "own" ]]; then 
    exit ${exitcode}
  else 
    set -e
    (exit ${exitcode}) && true
    return ${exitcode}
  fi
}

#################################### Archives #################################

# Args: filepath: absolute path of the file
function archive_ext_tools() {
  verbose "func ${FUNCNAME[0]} $@"
  local filepath="${1:-}"
  local filename=$(basename "${filepath}")
  local ext="${filename##*.}"
  local extract_path="${2:-${EXTRACTED_DIRNAME}}"
  verbose "archive_ext_tools ${ext} ${extract_path}"
  exsuccess=false
  case "${ext}" in
    "7z")
      if ${CONTENTS}; then
        options="l -slt -ba -r"
        files=$(7zz "${options}" "${filename}"|grep "Path"|awk -F"=" '{print$2}')
        # print_archive "${filepath}" "${files}"
      fi
      if ${UNARCHIVE}; then
        options=$(printf '\x2Dy')
        if 7zz e -aoa "${options}"  "${filepath}" -o"${extract_path}"; then
          echo "${filepath}" >> "${HISTORY}"
          exsuccess=true
        fi
      fi
      ;;
    "zip")
      if ${CONTENTS}; then
        files=$(zipinfo -1 "${filepath}")
      fi
      if ${UNARCHIVE}; then
        ui "extracting ${filepath} to ${extract_path}"
        verbose $(printf 'unzip -o -qo "%s" -d "%s"' "${filepath}" "${extract_path}")
        ARGS=( -qo "${filepath}" -d "${extract_path}" )
        unzip "${ARGS[@]}"
        if [ $? -eq 0 ]; then
          exsuccess=true
        else
          err "extract of ${filepath} failed with err ${exresult}"
        fi
      fi
      ;;
    "rar")
      if ${CONTENTS}; then
        files=$(unrar ltb "${filepath}"|grep "Name"|awk -F":" '{print$2}')
      fi
      if ${UNARCHIVE}; then
        if ! $(type -p unrar); then 
          err "Please install unrar before proceeding.  brew install rar works fine."
          endprog 1
        fi
        if unrar e -o+ -c- "${filepath}" -op "${extract_path}"; then 
          exsuccess=true
        fi
      fi
      ;;
    "tgz")
      if ${CONTENTS}; then
        files=$(tar -tf "${filepath}")
      fi
      if ${UNARCHIVE}; then 
        if tar -xf "${filepath}" -C "${extract_path}"; then
          exsuccess=true
        fi
      fi
      ;;
    *)
      err "not implemented"
      ;;
  esac
  if [ -n "${files}" ]; then 
    print_archive "${filepath}" "${files}"
    lisuccess=true
  fi
  if ${exsuccess}; then
      ui "recording an unarchive history"
      $(record_install_history "unarchive" "archive" "${filepath}")
    if ${SINGLE}; then
      if ${INSTALL}; then 
        ui "fixme"
        # ui "exploring what we just unarchiived"
        # export sa=$(pwd)
        # cd "${extract_path}"
        # eat_the_world_starting_at 0
        # cd "${sa}"
      fi
      return 0
    fi
  fi
}

function print_archive() {
  verbose "func ${FUNCNAME[0]} $@"
  local filename="${1:-}"
  local contents="${2:-}"
  IFS=$'\n'
  for line in ${contents}; do
    list_contents "${line}" "${filename}" 2
  done
}

function process_archive_file() {
  verbose "func ${FUNCNAME[0]} $1 $2"
  # set +x
  local filenamepath="${1:-}"
  local overwrite="${2:-false}"
  local wd="$(pwd)"
  # if [ -n "${filenamepath}" ]; then
  #   return 1
  # fi
  if ${LIST}; then
    list_tl "${filenamepath}"
  fi
  verbose "CONTENTS: ${CONTENTS} UNARCHIVE: ${UNARCHIVE}"
  if boolean_or ${CONTENTS} ${UNARCHIVE}; then
    verbose "processing ${filenamepath} for contents or unarchive"
    local filename=$(basename "${filenamepath}")
    local filebase="${filename%.*}"
    local extractpath="${wd}/${EXTRACTED_DIRNAME}/${filebase}"
    verbose "fn: ${filename} fb: ${filebase} ep: ${extractpath}"
    if ! mkdir -p "${extractpath}"; then
      extractpath="${downloads}/${EXTRACTED_DIRNAME}/${filebase}"
      ui "Error running mkdir in ${wd}, extracting in ${extractpath} instead"
      status=$(mkdir -p "${extractpath}")
    fi
    if ${overwrite}; then
      verbose "overwrite ${filenamepath} ${extractpath}"
      archive_ext_tools "${filenamepath}" "${extractpath}"
    elif grep -v "${filenamepath}" <<< "${HISTORY}"; then
      verbose "notyettouched ${filenamepath} ${extractpath}"
      archive_ext_tools "${filenamepath}" "${extractpath}"
    fi
  fi
}

function process_archives() {
  IFS=$' '
  failed=0
  for ext in ${ARCHIVE_EXTENSIONS}; do 
    count=0
    counts "${ext}"
    if gt ${count} 0; then
      gobblefind_by_ext "${ext}"
      for filenamepath in "${gobbled[@]}"; do 
        if ! process_archive_file "${filenamepath}" true; then
          ((failed++))
        fi
      done
    fi
  done
  return ${failed}

}

################################ PROCESS DMGS #################################

function attempt_unmount() {
  verbose "func ${FUNCNAME[0]} $@"
  local mounted="${1:-}"
  diskutil unmount "${mounted}"
  if [ $? -eq 0 ]; then
    MOUNTED=( "${MOUNTED[@]/${mounted}}" )
    return 0
  fi
  return 1
}

function attempt_unmounts() {
  for mounted in "${MOUNTED[@]}"; do
    attempt_unmount "${mounted}"
  done
}


function mount_dmg() {
  dmg="${1:-}"
  if [ -z "${dmg}" ]; then
    return 1
  fi
  mounted=""
  dmg_basename=$(basename "${dmg}")
  finddir_array -s "/Volumes"
  before_vols=( "${dirarray[@]}" )
  exout=$(hdiutil attach "${dmg}") 
  if stringContains "failed" "${exout}"; then
    finddir_array -s "/Volumes"
    after_vols=( "${dirarray[@]}" )
    diff_vols=$(diff <(echo $before_vols) <(echo $after_vols))
    if ! [ $? -gt 0 ]; then 
      err "Trying to mount the disk failed, sometimes that means its already"
      err "mounted.  If any of these are the software youre trying to"
      err "install, we can try to continue:"
      chosen=$(choices -r -s '\0' -c "${after_vols}")
      if [ $chosen -le ${#after_vols} ]; then 
        mounted="${after_vols[$chosen]}"
      else
        return {$chosen}
      fi
    else
      mounted=${diff_vols}
    fi

  elif stringContains "Usage" "${exout}"; then
    return 1
  fi
  mounted=$(echo "${exout}"|tr '\n' ' '|awk -F'\t' '{print$NF}'|xargs)
  if [ $? -gt 0 ]; then 
    err "failed to mount ${dmg}"
    return 1
  fi 
  echo "${mounted}"
  echo "${mounted}" > "${TRACKMOUNTS}"   
  MOUNTED+=( "${dmg_basename}" )
  return 0
}

process_dmg() {
  verbose "func ${FUNCNAME[0]} $@"
  local dmg="${1:-}"
  if ${LIST}; then
    list_tl "${dmg}"
  fi
  retval=255
  # attempt_unmounts
  if boolean_or ${CONTENTS} ${INSTALL}; then
    mounted=$(mount_dmg "${dmg}")
    verbose "mount retval $?"
    dmg_basename=$(basename "${dmg}")
    if ${CONTENTS}; then
      # gobblefind populates a global array called haggussed, which we will copy
      # to our own array with a more sensible name for readability, but also because
      # we'll need to reuse haggussed from inside the loop
      ARGS=( "${mounted}" )
      ex gobblefind 
      local files_on_dmg=("${haggussed[@]}")
      verbose "files_on_dmg: ${files_on_dmg[@]} haggussed: ${#haggussed[@]} ${haggussed[@]}"
      if gt ${#files_on_dmg[@]} 0; then
        IFS=$' '
        for filepath in "${files_on_dmg[@]}"; do
          verbose "dmg: ${dmg} filepath: ${filepath}"
          list_contents "${filepath}" "${dmg}"
          local filename=$(basename "${filepath}")
          if is_in_types "${filename}" "${PKG_EXTENSIONS}"; then
            # this prints the line for the content item, functions below will print
            # the contents or install if those flags are set
            list_package_contents "${filepath}" 2 "${dmg}"
          elif is_in_types "${filename}" "${APP_EXTENSIONS}"; then
            list_item "${filepath}"
          elif is_in_types "${filename}" "${ARCHIVE_EXTENSIONS}"; then
            process_archive_file "${filepath}"
          elif is_in_types "${filename}" "${DMG_EXTENSIONS}"; then
            process_dmg "${filepath}"
          fi
        done
      fi
    fi
    if boolean_or ${CONTENTS} ${INSTALL}; then
      export sd="$(pwd)"
      dmg_basename=$(basename "${dmg}")
      cd "${mounted}"
    fi
    if ${INSTALL}; then
      process_pkgs "${mounted}"
      retpkgs=$?
      process_apps "${mounted}"
      retapps=$?
      process_plugins "${mounted}"
      retplugins=$?
      process_dmgs "${mounted}"
      retdmgs=$?

      if boolean_or ${retpkgs} ${retapps} ${retplugins}; then
        retvals=( ${retpkgs} ${retapps} ${retplugins} )
        strleads=()
        for i in "${retvals[@]}"; do 
          case ${i} in
            0)
              strleads+=( "[✓]" )
              ;;
            1)
              strleads+=( "[ ]")
              ;;
          esac
        done
        ui "after mounting ${dmg} and looking for installables, we processed:"
        ui "   ${strleads[0]} pkgs ${strleads[1]} apps ${strleads[2]} plugins"
        ui "recording an install history"
        $(record_install_history "install" "image" "${dmg}")
        retval=0
      else
        err "could not find anything to install on ${dmg_basename}"
        retval=1
      fi
    fi
    if boolean_or ${CONTENTS} ${INSTALL} ; then
      cd "${sd}"
      sleep 1
      attempt_unmounts
    fi
  fi
  return ${retval}
}

function process_dmgs {
  verbose "process_dmgs: $(pwd)"
  IFS=$' '
  retvals=()
  for ext in ${DMG_EXTENSIONS}; do 
    count=0
    counts "${ext}"
    if gt ${count} 0; then
      gobblefind_by_ext "${ext}"
      for filenamepath in "${gobbled[@]}"; do 
        process_dmg "${filenamepath}" true
        retvals+=( $? )
      done
    fi
  done
  succeeded=0
  failed=0
  for ret in "${retvals[@]}"; do
    if gt ${ret} 0; then
      ((failed++))
    else
      ((succeeded++))
    fi
  done
  total=$((failed+succeeded))
  ui "of ${total} dmgs ${succeeded} succeeded ${failed} failed."
  if ! gt ${failed} 0; then
    return 0
  fi
  return 1
}

############################  App Processiing #################################

function aalias() {
  local target="${1:-}"
  if [ -n "${target}" ]; then
    if stat "${target}"; then
      local tbase=$(basename "${target}")
      tq=$(printf '%s' "${target}")
      tbq=$(printf '%s' "${tbase}")
  osascript <<END
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

function process_apps { 
  ext="${APP_EXTENSIONS}"
  verbose "process apps $@"
  count=0
  counts "${ext}"
  if gt ${count} 0; then
    gobblefind_by_ext "${ext}"
    for filenamepath in "${gobbled[@]}"; do 
      if process_app "${filenamepath}"; then 
        return 0
      else
        return $?
      fi
    done
  fi
}


# It seems rare that there would be more than one app in a dmg, but there might
# be in a backup and its easy enough to handle multiple anyway
# 
# Args: String app - absolute path of the app to be listed, shown 
#       contents, or installed
function process_app() {
  local app="${1:-}"
  local appname=$(basename "${app}")
  if ${CONTENTS}; then 
    gobblefind "${app}/"
    local files_in_contents=("${haggussed[@]}")
    verbose "files_in_contents: ${files_in_contents[@]} haggussed: "
    verbose "   ${#haggussed[@]} ${haggussed[@]}"
    if gt ${#files_in_contents[@]} 0; then
      IFS=$' '
      for filepath in "${files_in_contents[@]}"; do
        verbose "app: ${app} filepath: ${filepath}"
        list_contents "${filepath}" "${app}"   
      done
    fi
  fi
  if ${INSTALL}; then
    if [ -n "${ALT_INSTALL_LOC}" ]; then
      if sudo rsync $RSYNC_OPTS "${app}" "${ALT_INSTALL_LOC}/Applications"; then
        if "${ALT_INSTALL_ALIAS}"; then
          if ! aalias "${ALT_INSTALL_LOC}/Applications/${appname}"; then
            err "creating an alias in /Applications for "
            err "${ALT_INSTALL_LOC}/Applications/${app} failed."
          fi
        fi
        ui "recording an install history"
        $(record_install_history "install" "app" "${app}")    
        return 0
      else
        err "install to ${ALT_INSTALL_LOC} failed"
        if "${ALT_INST_FALLBACK}"; then 
          ui "attempting to install to /Applications since ALT_INST_FALLBACK is true."
        else
          return 1
        fi
      fi
    fi
    if sudo rsync $RSYNC_OPTS "${app}" "/Applications"; then
      $(record_install_history "install" "app" "${appname}")
      return 0
    else
      ret=$?
      err "install failed with error code ${ret}"
      return ${ret}
    fi
  fi      
}


########################### Package Processing ################################

function precedence_needed() {
  if [ -n "${ALT_INSTALL_LOC}" ]; then 
    if "${USER_INSTALL}"; then
      if "${ALT_INSTALL_FALLBACK}"; then  
        if "${USER_INSTALL_FALLBACK}"; then
          return 0
        fi
      fi
    fi
  fi
  return 1
}

function process_pkg() {
  pkg="${1:-}"
  if [ -z "${pkg}" ]; then
    return 1
  fi
  install_base_flags "${pkg}"
  if ${LIST}; then
    if stringContains "dmg" "${caller}"; then
      list_contents "${pkg}" "${caller}"
      local contents_layer=3
    else
      list_tl "${f}"
      local contents_layer=2
    fi
    if ${CONTENTS} && is_in_types "${pkg}" "${PKG_EXTENSIONS}"; then
      list_package_contents "${pkg}" ${contents_layer} "${caller}"
    fi
  fi
  if ${INSTALL}; then
    verbose "getting showChoiceChangesXML"
    # since some packages dont have any names or real info in 
    # showChoiceChanges, we're just going to turn all the options on
    installer -pkg "${pkg}" -showChoiceChangesXML |sed 's/0/1/g' > "$TMPDIR/${pkg}.xml"
    verbose "calling $(type -p installer) on ${pkg}"
    if ${PROMPT_FOR_ACTIONS}; then 
      confirm_yes $(printf "${PROMPT_INSTALL_PKG_EXPECTS_PKG}" "${pkg}")
    fi
    install_pkg
    return $?
  fi
}

function process_pkgs {
  verbose "process_pkgs in $(pwd)"
  local caller=caller
  local pkgtmp="${TMPDIR}/process_pkgs"
  mkdir -p "${pkgtmp}"
  count=0
  counts "${PKG_EXTENSIONS}"
  if gt ${count} 0; then
    IFS=$' '
    for ext in $PKG_EXTENSIONS; do 
      count=0
      counts "${ext}"
      if gt ${count} 0; then
        gobblefind_by_ext "${ext}"
        for f in "${gobbled[@]}"; do
          process_pkg "${f}"
        done
      fi
    done
  else
    err $(printf "${NOT_FOUND_EXPECTS_TYPE_EXTS_AND_DIR}" \
      "${PKG_TYPE_DESC}" "${PKG_EXTENSIONS}" "$(pwd)")
  fi
  return 1
}

function install_pkg() {
  flags=( "${INSTALL_BASE_FLAGS[@]}" "/" )
  if dump=$(sudo installer "${flags[@]}" -applyChoiceChangesXML "$TMPDIR/${pkg}.xml"); then 
    local pkg="${flags[2]}" # See INSTALL_BASE_FLAGS
    local bn=$(basename "${pkg}")
    ui "recording an install history"
    $(record_install_history "install" "package" "${pkg}")
    return 0
  else
    ret=$?
    err "installer ${flags[@]} failed with error code ${ret}"
    return ${ret}
  fi
}


# Args: filename to list contents of, must be pkg or mpkg
#       layer deep we are in listing contents, for display purposes
function list_package_contents() {
  verbose "func ${FUNCNAME[0]} $@"
  local f="${1:-}"
  local layer="${2:-2}"
  local parent="${3:-}"
  pdir="/tmp/list_package_contents"
  pkgdir="${pdir}/${f%.*}"
  if stat "${pkgdir@Q}"; then 
    verbose "creating timestampted tmp"
    local ts="$(date '+%Y%m%d %H:%M:%S')"
    pkgdir="${TMPDIR}/list_package_contents/${f%.*}/${ts}"
    
  fi
  mkdir -p "${pkgdir}"
  if ! pkgutil --expand "${f}" "${pkgdir}/pkg"; then
    non_fatal_error_request "$rc" "pkgutil --expand \"${f}\" \"${pkgdir}/pkg\""
  fi
  local paxfiles=()
  ARGS=( "${pkgdir}" )
  ex gobblefind 
  for file in "${haggussed[@]}"; do 
    if stringContains "bom" "${file}"; then
      local bomfile="${file}"
    elif stringContains "pax" "${file}"; then
      paxfiles+=("${file}")
    else
      list_contents "${file}" "${f}" ${layer} "${parent}"
    fi
  done
  if [ -n "${bomfile}" ]; then
    bomcontents=$(lsbom "${bomfile}")
    local lineno=0
    for line in ${bomcontents}; do
      ((lineno+=1)) 
      list_special_pacakage_file "bom" "${file}" ${lineno} "${line}" ${layer} \
        "${f}" "${parent}"
      verbose "bomcontents: ${line}"
    done
  fi
  if gt ${#paxfiles[@]} 0; then
    for paxfile in "${paxfiles[@]}"; do
      # ui "pax file: ${paxfile} with contents:"
      if [[ "${paxfile}" == *.gz ]]; then 
        paxcontents=$(gzcat "${paxfile}" | pax)
      elif [[ "${paxfile}" == *.xz ]]; then
        paxcontents=$(xzcat "${paxfile}" | pax)
      elif [[ "${paxfile}" == *.pax ]]; then 
        paxcontents=$(pax < "${paxfile}")
      else 
        err "${PAXFILE_ERR}"
      fi
      if [ -n "${paxcontents}" ]; then
        for line in ${paxconents}; do 
          list_special_pacakage_file "pax" "${file}" ${lineno} "${line}" \
            ${layer} "${f}" "${parent}"
          verbose "paxcontents (${paxfile}): ${line}"
        done
      fi
    done
  fi
}

############################## Audio Plugins ##################################

function get_plugin_dest_from_ext_and_base() {
  verbose "func ${FUNCNAME[0]} $@"
  local ext="${1:-}"
  local destbase="${2:-}"
    case  "${ext}" in
    "vst")
      dest="${destbase}/VST/"
      ;;
    "vst3")
      dest="${destbase}/VST3/"
      ;;
    "component")
      dest="${destbase}/Components/"
      ;;
    *)
      err "Unable to parse ${path} as a plugin.  Apologies."
      rreturn 2
      ;;
  esac
  echo "${dest}"
}

# args: the absolute of the plugin to install
function process_plugin() {
  verbose "func ${FUNCNAME[0]} $@"
  local path="${1-}"
  local filename=$(basename "${path}")
  local ext=$(echo "${path}"|awk -F'.' '{print$NF}'|sed 's:/::g')
  local rsync_opts='-rltv'
  # echo "installing ${path} to ${dest}"
  # command=$(printf "${commandstrf}" "${path}" "${dest}")
  # verbose "running ${command}"
  if $SYSTEM_PLUGIN_DIRS; then
    local destbase="${SYSTEM_PLUGROOT}"
    local dest=$(get_plugin_dest_from_ext_and_base "${ext}" "${destbase}")
    ui  $(printf "${INSTALLING_FILE_TO_DEST_EXPECTS_FILE_AND_DEST}" \
        "${filename}" "${dest}")
    if ${PROMPT_FOR_ACTIONS}; then
      confirm_yes "OK?"
    fi
    if ! sudo rsync "${rsync_opts}" "${path}" "${dest}"; then
      err "install failed with error code $?"
    else
      syspluginstalled=true
    fi
  else
    local destbase="${USER_PLUGROOT}"
    local dest=$(get_plugin_dest_from_ext_and_base "${ext}" "${destbase}")
    ui $(printf "${INSTALLING_FILE_TO_DEST_EXPECTS_FILE_AND_DEST}" \
        "${filename}" "${dest}")
    if ${PROMPT_FOR_ACTIONS}; then
      confirm_yes "OK?"
    fi
    if ! rsync "${rsync_opts}" "${path}" "${dest}"; then
      ß
      err "install failed with error code ${ret}"
           
    else
     userpluginstalled=true

    fi
  fi
  if boolean_or "${syspluginstalled}" "${userpluginstalled}"; then
      ui "recording an install history"
      $(record_install_history "install" "plugin" "${path}")
      return 0
    fi
  return 1
}

function process_plugins {
  verbose "PLUGIN_EXTENSIONS ${PLUGIN_EXTENSIONS}"
  IFS=$' '
  for ext in ${PLUGIN_EXTENSIONS}; do
    verbose "ext ${ext}"
    gobblefind_by_ext "${ext}"
    verbose "count ${#gobbled[@]} like ${gobbled[0]}"
    for plug in "${gobbled[@]}"; do 
      verbose "operating on ${plug}"
      if ${LIST}; then
        list_tl "${plug}"
      fi 
      if ${CONTENTS}; then
        ARGS=( "${plug}/" )
        ex gobblefind 
        for file in "${haggussed[@]}"; do
          list_contents "${file}" "${plug}"
          verbose $(printf "plugindir: %s contentfile: %s" "${plug}" "${file}")
        done
      fi
      if ${INSTALL}; then
        if process_plugin "${plug}"; then
          return 0
        else
          return $?
        fi
      fi
    done
  done
  return 1
}

#... append at the end
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
      mv "$path" ~/.Trash/"$dst"
    fi
  done
}

function extension_match() {
  local file="${1:-}"
  exts="${PLUGIN_EXTENSIONS}"
  ord=$(echo "${exts}"|tr " " "|")
  or_regex=$(printf '(%s)' "${ord}")
  verbose "grep ${or_regex} file ${file}"
  grep -E "${or_regex}" <(echo "${file}")
  return $?
}

# adds all installed plugins to a global array INSTALLED_PLUGINS, along the way populates
# SYS_INSTALLED_VSTS, USER_INSTALLED_VSTS, SYS_INSTALLED_VST3S, USER_INSTALLED_VST3S,
# SYS_INSTALLED_AUS, USER_INSTALLED_AUS,
# INSTALLED_VSTS, INSTALLED_VST3S, INSTALLED_AUS
# These arrays are sorted after being populated
function get_all_installed_plugins() {
  swd="$(pwd)"
  cd "${SYSTEM_PLUGROOT}/VST"
  ARGS=( "vst" )
  ex gobblefind_by_ext 

  SYS_INSTALLED_VSTS=( "${gobbled[@]}" )
  echo "${SYS_INSTALLED_VSTS[@]}"
  cd "${USER_PLUGROOT}/VST"  
  ARGS=( "vst" )
  ex gobblefind_by_ext

  USER_INSTALLED_VSTS=( "${gobbled[@]}" )
  INSTALLED_VSTS=( "${SYS_INSTALLED_VSTS[@]}" "${USER_INSTALLED_VSTS[@]}" )
  cd "${SYSTEM_PLUGROOT}/VST3"
  ARGS=( "vst3" )
  ex gobblefind_by_ext 
  
  SYS_INSTALLED_VST3S=( "${gobbled[@]}" )
  cd "${USER_PLUGROOT}/VST3"  
  gobbled=() 
  ARGS=( "vst3" )
  ex gobblefind_by_ext 

  USER_INSTALLED_VST3S=( "${gobbled[@]}" )
  INSTALLED_VST3S=( "${SYS_INSTALLED_VST3S[@]}" "${USER_INSTALLED_VST3S[@]}" )
  cd "${SYSTEM_PLUGROOT}/Components"
  ARGS=( "component" )
  ex gobblefind_by_ext 
  sleep 5
  SYS_INSTALLED_AUS=( "${gobbled[@]}" )
  sleep 4
  cd "${USER_PLUGROOT}/Components"  
  echo "${SYS_INSTALLED_AUS[@]}"
  ARGS=( "component" )
  ex gobblefind_by_ext 

  USER_INSTALLED_AUS=( "${gobbled[@]}" )
  INSTALLED_AUS=( "${SYS_INSTALLED_AUS[@]}" "${USER_INSTALLED_AUS[@]}" )
  INSTALLED_PLUGINS=( "${INSTALLED_VSTS[@]}" "${INSTALLED_VST3S[@]}" "${INSTALLED_AUS[@]}" )
  cd "${swd}"
}

# This is intended to be a blocking subshell execution call.  It was
# implemented in rather a silly way attempting to reduce variables in 
# solving problems i didn't understand, and it just, surprise surprise
# created more problems.  Until i've audited the code to see that its 
# not used, its staying, but yeah, probably, just, dont.
function ex() {
  exout=""
  exresult=666
  d="$(date +%s)"
  tempfile="${TMPDIR}/exfinished.${d}"
  tracktmp="/tmp/bellicose/ex.$1.${d}"
  mkdir -p ${tracktmp}
  trackcmd="${tracktmp}/$1"
  trackout="${tracktmp}/$1.exout" 
  trackret="${tracktmp}/$1.ret"
  printf '%s %s\n' "$@" "${ARGS[@]}" > "${trackcmd}"
  (
    exec 2>&1
    exec > "${trackout}"
    "$@" "${ARGS[@]}"  
    ret=$?
    echo "retval ${ret}" > "${trackret}"
    touch "${tempfile}"
    exit ${ret}
  )
  while ! test -f "${tempfile}"; do sleep 1; done
  rm "${tempfile}"
  cat "${trackout}"
  return $(cat "${trackret}"|awk '{print$2}')
}

# populates a global DMG_PLUGINS with the plugins on the DMG given in arg 1
function get_plugins_on_dmg() {
  dmg="${1:-}"
  if [ -z "${dmg}" ]; then
    return 1
  fi
  ARGS=( "${dmg}" )
  if ex mount_dmg; then
    swd="$(pwd)"
    cd "${mounted}"
    ARGS=( "vst" )
    ex gobblefind_by_ext 
    DMG_VSTS=( "${gobbled[@]}" )
    sort_array "${DMG_VSTS[@]}"
    ARGS=( "vst3" )
    ex gobblefind_by_ext 
    DMG_VST3S=( "${gobbled[@]}" )
    sort_array "${DMG_VST3S[@]}"
    ARGS=( "component" )
    ex gobblefind_by_ext
    DMG_AUS=( "${gobbled[@]}" )
    sort_array "${DMG_AUS[@]}"
    DMG_PLUGINS=( "${DMG_VSTS[@]}" "${DMG_VST3S[@]}" "${DMG_AUS[@]}" ) 
    cd "${swd}"
    ARGS=( "unmount" "${mounted}" )
    ex diskutil
  else
    err "failed to mount ${dmg}"
    exit 1
  fi
}

# based on plugins found in a given original install medium, update the modification
# dates of the currently installed versions (for easier grouping / discovery later)
function update_mod_times() {
  dmg="${1:-}"
  if [ -z "${dmg}" ]; then
    return 1
  fi
  get_all_installed_plugins
  get_plugins_on_dmg "${dmg}"
  same_plugin_same_type_diff_location "${INSTALLED_PLUGINS}" "${DMG_PLUGINS}"
  ui "requesting sudo for touch in system directories"
  for plugin in "${SAMESAMEDIFF[@]}"; do 
    sudo touch "${plugin}"
  done
}

# based on plugins found in a given original install medium, remove any of
# those plugins from installed directories
function uninstall_plugins() {
  #dmg="${1:-}"
  #rm_to="${2:-}"
  if [ -z "${dmg}" ]; then
    return 1
  fi
  if ! stat "${dmg}"; then
    return 1
  fi
  if [ -n "${rm_to}" ]; then
    if ! mkdir -p "${rm_to}"; then
      err "mkdir -p ${rm_to} failed with return code $?"
      return 1
    fi
  fi
  get_plugins_on_dmg "${dmg}"
  get_all_installed_plugins
  if gt "${#DMG_PLUGINS[@]}" 0; then 
    for disk_file in "${DMG_PLUGINS[@]}"; do
      if extensiom_natch "${disk_file}"; then
        disk_filename=$(basename "${disk_file}") 
        verbose "looking for ${disk_filename}"
        for installed_file in "${INSTALLED_PLUGINS[@]}"; do
          if stringContains "${disk_filename}" "${installed_file}"; then
            ui "uninstalling ${installed_file}"
            if [ -n "${rm_tp}" ]; then 
              if ! sudo rsync "${RSYNC_OPTS}" "${installed_file}" "${rm_to}"; then
                err "return code $? while trying to rm ${installed_file} ro ${rm_to}"
              fi
            else
              ssudo trash "${installed_file}"
            fi
          fi
        done
      fi
    done
  fi
  cd "${swd}"
}

################################# Cleanup #####################################
# This isn't really used anymore, probably won't do what you want it to without
# significant modification, and should probably be yanked, printed on a
# dotmatrix printer, the kind with the guide strips you had to setup and then
# tear off after printing, you should have to listen to that dotmatrix sound 
# of two robots brains being smooshed together and then torn in half, and then
# when you're done and have the printed code, you should burn it.

function bellibackup {
  verbose "backup in $(pwd)"
  local working_dir=$(find ~+ -type d -maxdepth 0 2> /dev/null)
  local download_root=$(echo $working_dir|awk -F'/' '{print$5}')
  local downloads="$HOME/Downloads"
  verbose "Running backup from ${working_dir} with download root ${download_root}"
  local dir_to_back="${working_dir}"
  if [ -n "${download_root}" ]; then
    if ! stringContains "${download_root}" "${BACKUP_EXCLUDED_DIRS}"; then 
      dir_to_back="${downloads}/${download_root}"
    fi
  fi
  verbose "asking for user confirmation on backup to ${dir_to_back}"
  status=$(timed_confirm_yes "Backing up ${dir_to_back}")
  if [ $? == 255 ]; then 
    rreturn 2
  fi
  verbose "proceeding with backup, $? status, ${status} from timed_confirm_yes"
  secondaries=$(find ~+ -type f -iname "${SECONDARY_CRITERIA}" 2> /dev/null)
  secondarycount=$(echo "${secondaries}"|wc -l)
  cd "${downloads}" # so we're not in a dir we're moving
  if gt ${secondarycount} 0; then
    ui $(printf "${INSTALLING_FILE_TO_DEST_EXPECTS_FILE_AND_DEST}" 
      "${secondarycount}" "${SECONDARY_CRITERIA}" "${SECONDARY_BACKUP_DIR}")
    if ! rsync "${RSYNC_OPTS}" "${dir_to_back}" "${SECONDARY_BACKUP_DIR}"; then
      err "secondary backup failed."
    fi
  fi
  ui $(printf "${BACKUP_STR_EXPECTS_SRC_DEST}" "${dir_to_back}" \
    "${BACKUP}")
  rsync "${RSYNC_OPTS}" "${dir_to_back}" "${BACKUP}"
  # out of excessive caution, move to tmp instead of rm -rf
  # reboot will delete, but if we screwed up, we can recover  
  datestr=$(date "+%Y%m%d%H%M")
  movedir="/tmp/$datestr"
  verbose "copying ${dir_to_back} to ${movedir} in place of rm -rf"
  mv "${dir_to_back}" "${movedir}"
}

############################# Main Program Code ###############################

function help() {
  ui "help not yet implemented" # HAHAHAHAHAHAHAHAHAHAHAHAHAHA
}

# This looks like a particularly silly wrapper function that does... basically
# nothing except let me call a function "eat_the_world_starting_at" which 
# looks much cooler than "handle_cache_by_type"
function eat_the_world_starting_at() {
  local start="${1:-0}"
  if lt ${start} 5; then
    local IFS=$'\n'
    for i in $(seq ${start} 4); do 
      handle_cache_by_type ${i}
    done
  fi
}

# Run bellicose in single file mode, after which if we think we succeeded, 
# we thank you.  Because you're WORTHY of it.
function process_single() {
  local file="${1:-}"
  if ! [ -f  "${file}" ]; then
    err "could not find a file at ${file}, please try again."
    exit 1
  fi
  if process_file "${file}"; then 
    ui ""
    ui "Success! Thanks for trying bellicose --"
    ui "if you liked it drop me a note and say hello,"
    ui "or paypal me some money for a coffee or someting."
    ui ""
    exit 0
  else
    err "Something went wrong alone te way, but we couldn't"
    err "figure out what without more information."
    err "If you'd like help with your issue or to help us fix"
    err "bugs, run that last one again with -R and email"
    err "or open a githunb issue with the resulting report file."
    err ""
    exit 1
  fi
}


# function create_cache() {
#   local path="${1:-}"
#   if [ -n  "${path}" ]; then 
#     bn=$(basename "${path}")
#     dn=$(dirname "${path}")
#     if ! [ -d "${dn}" ]; then 
#       mkdir -p "${dn}"
#     fi
#     if ! [ -f "${bn}" ]; then 
#       touch "${path}"
#     fi
#   fi
# }

# To be called after user args have been parsed
function setup_env() {
  verbose "running mkdir -p ${CACHE}"
  mkdir -p "${CACHE}"
  if ! [ -f "${HISTORY}" ]; then 
    touch "${HISTORY}"
  fi
  # in session tracking, so we can unmount
  declare -ga MOUNTED

  if [[ "${LOGFILE}" != "/dev/stderr" ]]; then
    exec 2> >(tee -a -i "${LOGFILE}")
  fi

  declare -ga NEW_ARCHIVES
  declare -ga NEW_DMGS
  declare -ga NEW_APPS
  declare -ga NEW_PKGS
  declare -ga NEW_PLUGS
}

function single() {
  printf -v file "%s" "${1:-}"
  echo $(ls -alh "${file}")
  if ! [ -f "${file}" ]||[ -d "${file}" ]; then
    file="$@"
    if ! [ -f "${file}" ]||[ -d "${file}" ]; then
      err "${COULD_NOT_PARSE}"
      exit 1
    fi
  fi
  ui "Operating in single file mode on ${file}"
  SINGLE=true
  INSTALL=true
  if completed "${file}"; then
    ui $(printf "${FOUND_IN_CACHE}" "${file}")
    confirm_yes "${TRY_AGAIN_POSSIBLY_OVERWRITE}"
  fi
  process_single "${file}"
  return $?
}

function main() {
  export LIST=false
  export CONTENTS=false
  export SYSTEM_PLUGIN_DIRS=false
  export INSTALL=false
  export UNARCHIVE=false
  export LOGFILE="/dev/stderr"
  export VERBOSE=false
  # export DMG=false
  # export PKG=false
  # export AUDIOPLUGIN=false
  export SINGLE=false 
  SKIPUNARCHIVE=false

  optspec="svf:VR:S"
  while getopts "${optspec}" optchar; do #  --long system_plugin_dirs,verbose,logfile,version,report,skip_unarchive -- "$@")
  #while [[ $# -gt 0 ]]; do
    case "${optchar}" in
      s)
        SYSTEM_PLUGIN_DIRS=true        
        ;;
      # TODO add -p plugin install dir
      v)
        VERBOSE=true
        verbose "running in verbose mode"
        ;;
      f)
        LOGFILE="${OPTARG}"
        ;;
      V)
        echo "0.1"
        ;;
      R)
        LIST=true
        CONTENTS=true
        VERBOSE=true
        LOGFILE="${OPTARG}"     
        ;;
      S)
        SKIPUNARCHIVE=true       
        ;;
      ?)
        # POSITIONAL_ARGS+=("${1-}") 
        # shift 
        help
        ;;
    esac
  done
  chosen_mode="${@:$OPTIND:1}"
  ui "Chosen mode: ${chosen_mode}"
  unset single_file
  if [ -n "${@:$OPTIND+1:1}" ]; then
    single_file="${@:$OPTIND+1}" 
    if [ -n "${single_file}" ]; then
      if ! $SKIPUNARCHIVE; then 
        UNARCHIVE=true
      fi
      INSTALL=true
      
      single "${single_file}"
    fi
  fi
  setup_env
  # https://stackoverflow.com/questions/7577052/bash-empty-array-expansion-with-set-u
  # prevent unbound variable on POSITIONAL_ARGS
  # set -- ${POSITIONAL_ARGS[@]+"${POSITIONAL_ARGS[@]}"}


  # trap 'trap - ERR RETURN; kill -INT $$ ; echo "fatal error"; return' ERR RETURN
  # for arg in "${POSITIONAL_ARGS[@]}"; do
  case ${chosen_mode} in
    "list")
      LIST=true
      eat_the_world_starting_at 0
      ;;
    "contents")
      LIST=true
      CONTENTS=true
      eat_the_world_starting_at 0
      return 0
      ;;
    "unarchive")
      if ! ${SKIPUNARCHIVE} > /dev/null; then
        UNARCHIVE=true
        eat_the_world_starting_at 0
        return 0
      fi
      ;;
    "install")
      if ! ${SKIPUNARCHIVE} > /dev/null;  then
        UNARCHIVE=true
      fi
      INSTALL=true
      eat_the_world_starting_at 0
      return 0
      ;;
    "installed")
      cat "${history}"
      return 0
      ;;
  esac

  err "please give me an action, one of:"
  err "   unarchive"
  err "   install (unarchive implied unless -S U)"

}

#  from https://stackoverflow.com/questions/2683279/how-to-detect-if-a-script-is-being-sourced
# As $_ could be used only once, uncomment one of two following lines

# printf '_="%s", 0="%s" and BASH_SOURCE="%s"\n' "$_" "$0" "$BASH_SOURCE" 
[[ "$_" != "$0" ]] && DW_PURPOSE=sourced || DW_PURPOSE=subshell

[ "$0" = "$BASH_SOURCE" ] && BASH_KIND_ENV=own || BASH_KIND_ENV=sourced; 
verbose "proc: $$[ppid:$PPID] is $BASH_KIND_ENV (DW purpose: $DW_PURPOSE)"

if [[ $BASH_KIND_ENV == "own" ]]; then 
  ui "bellicose can damage your system if you don't know what you're doing."
  ui "please exercise caution.  The authors accept no liability for any"
  ui "use of this software for any purpose."
  ui ""
  if ! declare -pF "confirm_yes" > /dev/null 2>&1; then 
    source "$D/user_prompts.sh"
  fi
  if confirm_yes "Proceed with attempting $@ using files in $(pwd)?"; then
    main $@
  fi
fi
