############################## Configuration ##################################

# Actions are explicit, so by default we don't prompt before taking them,
# but if you change below to true, we will ask a lot of questions
PROMPT_FOR_ACTIONS=true

# Never look for known types in dirs that look like the following:
EXCLUDE_DIR='.app'

# (not yet implemented)
# User File Types: As a best effort, if enabled with adequate criteria, we 
#                  will try to copy any other filetype we find along the way
#                  to a location of your choice, based on a file extension or 
#                  a regex.
USER_EXTENSIONS=false
USER_EXT_TYPE_DESC="user specified (by ext)"
# Extensions are matched as the final characters in a file or directory name 
# following a dot.  See below for examples.  They should be space separated in 
# the string below.
USER_EXTENSIONS=""

USER_REGEXS=false
USER_REGEX_TYPE_DESC="user specified (by regex)"
# Regexes should be greppable and should be specified individually within 
# single quotes, placed space separated (for more than one) in the string 
# below.  If you only have one, you should still enclose in single quotes
# so it looks like USER_REGEX="'my.*complicated\ regex'"
USER_REGEX=""

# (not yet implemented)
# Documentation: As a best effort, we will look for documentation included
#                within or beside any of the below types, and if enabled, 
#                copy it to ~/Documents or wherever specified below.  This
#                is disabled by default.
DOCUMENTATION=false
DOC_TYPE_DESC="documentation"
DOC_EXTENSIONS="doc rtf pdf nfo txt"

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

# Plugins are generally stored in the system-wide plugin directory in /Library
# but can also be installed in the users ~/Library, subdirectories of these, or
# in some cases, somewhere else entirely.  We default to the user's library,
# but you can chagnge that here or at runtime with the -s flag.
SYSTEM_PLUGIN_DIRS=false
SYSTEM_PLUGROOT="/Library/Audio/Plug-Ins"
USER_PLUGROOT="${HOME}${SYSTEM_PLUGROOT}"

# (not yet implemented)
# When finished processing the above files we can deal with the sources for 
# you (again, best effort) in a few ways.  By default, we do nothing with them.
# we leave both the source files and our "workroom materials" where they were, 
# assuming there may be other things you want to inspect in say, expanded 
# archives.  Choices:
# 1. (default) leave as-is
# 2. delete files created by bellicose, leave source files as-is
# 3. if successfully installed, delete (3a) or trash source files (3b)
#    to include the filetypes listed above including ALL UNTOUCHED FILES...
#    files in archives, on disk images, etc, that we know nothing about.
# 4. Backup source files to a specified location (or multiple locations,
#    given additional criteria).
CLEANUP=false # same as CLEANUP_TYPE=1, to enable one of the other options,
              # set this to true and provide the numbered type below
              # for 3a and 3b, just CLEANUP_TYPE=3 and DELETE=false if you
              # prefer the trash
CLEANUP_TYPE=1
CLEANUP_TYPE_DESCS=( "as-is" "delete_created" "delete_all" "backup" )

DELETE=false

# Backup is done with rsync, so can be a local directory or a remote
# ssh location, specified as you would expect for rsync.
BACKUP="$HOME/Downloads/Plugins/_installed_federation/"

RSYNC_OPTS="-rlutv"

BACKUP_EXCLUDED_DIRS="instruments Plugins DAWs drivers Samples Plug-Ins Windows"

# Secondary backup should be enabled by setting to true and populating
# glob or regex (as supplied to the "find" command) fields below.  
# We will look for both and more than one of each if provided as space 
# separated single quoted strings within the double quotes below.
# Secondary backup is ignored if we're not in cleanup mode 4.
SECONDARY_BACKUP=true
SECONDARY_BACKUP_GLOB="*.exe"
SECONDARY_BACKUP_REGEX=""

# bellicose uses a few types of "workworm material" space, which we try to do
# in a user-courteous way consistent with MacOS norms, but you may change the 
# defaults below.
# 1. We cache the names of all filee of the types listed above as we've seen 
#    them, and if you try to process the same file multiple times (because it
#    came packaged in multiple archives, for instance), you can choose to skip
#    processing the same file again at runtime.  We don't do any version check
#    so you may get false positives if a software distributor always uses the 
#    same filename for updates.  Within the cache directory, we keep a simple 
#    text file for each type above, within the text file is just a list of \n
#    separated file names.
# 2. We use space to unarchive compressed files.  This defaults to a created
#    directory in whatever working directory you launched bellicose from. It
#    is sometimes conveneint to launch it from read only media, so a fallback
#    should be provided.  We default to ~/Downloads.  In either case, we create
#    a directory named "bellicose_extracted" and folders within that 
#    named correspondingly with the archive they were generated from. If 
#    one of the unarchive tools goes screwball, we try to fallback to 
#    directories we created (at worst). 
#    To not see any workroom materials, change the location to be a
#    subdirectory of TMPDIR, which the system will cleanup for us, something 
#    like WORKROOM_MATERIALS="${TMPDIR}/wm".  If it doesn't exist, we'll create
#    it on the way.
# 3. We use a temp directory as a root for mountpoints for disk image files.
#    Optionally, you can configure so they're mounted under /Volumes as usual.
#    the temp location means they're hidden in the finder.  Disk utility isn't
#    always friendly about unmounting, and there's generally no harm to not 
#    forcing it, but its annoying to see them hanging around in the finder.

# cross session tracking, so we can (optionally) not unarchive, reinstall, 
# etc, unless that was intended
CACHE="$HOME/Library/Caches/bellicose"

EXTRACTED_DIRNAME="bellicose_extracted"
WORKROOM_MATERIALS_FALLBACK="${HOME}/Downloads"

# The existence and locations of files we want to keep track of 
# while running (so that we can extract and install them)
# we will track in a temp folder... this will also be the parent
# directory where we mount image files during the install. 
# we declare it here and trap is so that it is cleaned up on 
# abnormal exit
TMPDIR=$(mktemp -d)
if $DEBUG; then echo "storing temp files in ${TMPDIR}"; fi
function finish() {
  if ! ${DEBUG}; then
    >&2 printf "removing TMPDIR"
    rm -rf "${TMPDIR}"
  fi
}
trap finish EXIT

# We grab the working directory at launch so we don't have to 
# call pwd all over the place.  We don't go to great lengths to
# protect system resources.  Be warned.
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

ACTIONS=()
ACTIONS+=( "${UNARCHIVE}" )
ACTIONS+=( "${INSTALL}" )
ACTIONS+=( "${INSTALL}" )
ACTIONS+=( "${INSTALL}" )
ACTIONS+=( "${INSTALL}" )

UNCACHED=()
UNCACHED+=( "${NEW_ARCHIVES[@]}" )
UNCACHED+=( "${NEW_DMGS[@]}" )
UNCACHED+=( "${NEW_APPS[@]}" )
UNCACHED+=( "${NEW_PKGS[@]}" )
UNCACHED+=( "${NEW_PLUGINS[@]}" )

CACHES=()
CACHES+=( "${ARCHIVED}" )
CACHES+=( "${DMGED}" )
CACHES+=( "${APPED}" )
CACHES+=( "${PKGED}" )
CACHES+=( "${PLUGGED}" )

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
  printf "${LOG_TEMPLATE}" "(${loglevel})" "${ts}" "${BASH_LINENO[-3]}" \
      "${FUNCNAME[-3]}" "${FUNCNAME[-2]}" "${message}" > "${LOGFILE}"
}

# Args: String  - message, log message to be printed
# Globals: LOGFILE
function err() {
  verbose "function_call $@"
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
  verbose "function_call $@"
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
  verbose "function_call $@"
  local return_code="${1:-}"
  while [ ${return_code} -gt 0 ]; do
    stacktrace
    err $(printf "${FATAL_ERR}" "${return_code}" "${FUNCNAME[-1]}")
    echo
    confirm_yes "${CONTROL_C_LOOP}"
  done
}

######################### List and Content Functions ##########################


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
  verbose "function_call $@"
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
  verbose "function_call $@"
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
  verbose "function_call $@"
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
  verbose "function_call $@"
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

function count_space_separated {
  local to_count="${1:-}"
  IFS=$' '
  count=0
  for thing in ${to_count}; do
    ((count+=1))
  done
  return $count  
}

regex_or_builder() {
  verbose "function_call $@"
  local space_separated_regexes="${1:-}"
  regex=""
  count_space_separated "${space_seuparated_regexes}"
  if [ ${count} -gt 1 ]; then 
    exclude_p_regex="(%s)"
    buildee=""
    i=0
    for regex in "${EXCLUDE_DIRS_REGEXES}"; do
      ((i+=1))
      if [ i -eq 1 ]; then
        buildee=$(printf '%s' "${regex}")
      else
        buildee+=$(printf '|%s' "${rregex}")
      fi
    done
    regex=$(printf '(%s)' "${buildee}")
    return 0
  else 
    regex="${space_separated_regexes}"
    return 0
  fi
  return 1
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


# Prompt to confirm, defaulting to YES on <enter>
# Args: String to prompt the user with - defaults to "Are you sure?"
function confirm_yes {
  local prompt="${*:-Are you sure} [Y/n]? "
  get_yes_keypress "$prompt" 0
}

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
  $(echo "$2"|grep -Eqi "$1");
  return $?;
}

function bash_major_version() {
  echo "${BASH_VERSINFO[0]}"
}

function bash_minor_version() {
  echo "${BASH_VERSINFO[1]}"
}

function bash_version() {
  major=$(bash_major_version)
  minor=$(bash_minor_version)
  echo "${major}.${minor}"
}

# stolen from https://stackoverflow.com/questions/8654051/how-can-i-compare-two-floating-point-numbers-in-bash
is_first_floating_number_bigger () {
    number1="$1"
    number2="$2"

    [ ${number1%.*} -eq ${number2%.*} ] && [ ${number1#*.} \> ${number2#*.} ] || [ ${number1%.*} -gt ${number2%.*} ];
    result=$?
    if [ "$result" -eq 0 ]; then result=1; else result=0; fi

    __FUNCTION_RETURN="${result}"
}

# Args: filename: a filename to check
#       extension_list: a space delimited string of filename extensions
# Returns 0 if filename does end in one of the extensions, 1 otherwise
function is_in_types() {
  verbose "function_call $@"
  local f="${1:-}"
  local exts="${2:-}"
  local regex=""
  for ext in ${exts}; do
    regex+=$(printf '.*.%s$||' "${ext}")
  done
  # remove the last || from the term
  regex="${regex%??}"
  return grep "${regex}" <(echo "${f}")
}

function counts_with_completed {
  local extensions="${1:-}"
  IFS=$' '
  for ext in ${extensions}; do
    gobblefind_by_ext "${ext}"
    for filename in "${gobbled[@]}"; do 
      if completed "${filename}"; then
        ((cached_count+=1))
      else
        local fext="${filename##*.}"
        if stringContains "${fext}" "${ARCHIVE_EXTENSIONS}"; then
          NEW_ARCHIVES+=( "${filename}" )
        elif stringContains "${fext}" "${DMG_EXTENSIONS}"; then
          NEW_DMGS+=( "${filename}" )
        elif stringContains "${fext}" "${APP_EXTENSIONS}"; then
          NEW_APPS+=( "${filename}" )
        elif stringContains "${fext}" "${PKG_EXTENSIONS}"; then
          NEW_PKGS+=( "${filename}" )
        elif stringContains "${fext}" "${PLUGIN_EXTENSIONS}"; then
          NEW_PLUGS+=( "${filename}" )
        fi
      fi
      ((total_count+=1))
    done
  done
  verbose "count:${total_count} cached_count:${cached_count}"
}

function counts {
  local extensions="${1:-}"
  count=0 # return value, total count of files for provided extentions

  local ext # iterator over ${extensions}
  IFS=$' '
  for ext in ${extensions}; do
    if stringContains "${ext}" "${EXCLUDE_DIR}"; then
      verbose "counting apps"
      local_count=$(find ~+ -name "*.${ext}" |wc -l|xargs)
    else
      local_count=$(find ~+ -type f -name "*.${ext}" |grep -v "${EXCLUDE_DIR}" |wc -l|xargs)
    fi
    verbose "$ext $local_count $count"
    ((count += $local_count))
  done

  return ${count}
}

# Args: filename
# Returns: 0 if this file is in the cache as already processed, 1 otherwise
function completed {
  local filepath="${1:-}"
  local filename=$(basename "${filepath}")
  local ext="${filename##*.}"
  verbose "checking completed ${filepath}"
  if stringContains "${ext}" "${ARCHIVE_EXTENSIONS}"; then
    grep "${filepath}" <(echo "${UNARCHIVED}")
    if [ $? -eq 0 ]; then
      verbose "${filename} in cache"
      return 0
    fi
  elif stringContains "${ext}" "${DMG_EXTENSIONS}"; then
    grep "${filepath}" <(echo "${INSTALLED}")
    if [ $? -eq 0 ]; then
      verbose "${filename} in cache"
      return 0
    fi
  elif stringContains "${ext}" "${APP_EXTENSIONS}"; then
    grep "${filepath}" <(echo "${APPED}")
    if [ $? -eq 0 ]; then
      verbose "${filename} in cache"
      return 0
    fi
  elif stringContains "${ext}" "${PKG_EXTENSIONS}"; then
    grep "${filepath}" <(echo "${INSTALLED}")
    return $?
  elif stringContains "${ext}" "${PLUGIN_EXTENSIONS}"; then
    grep "${filepath}" <(echo "${PLUGGED}")
    return $?
  else
    return 1
  fi
}

uncompleted_larger() {
  verbose "function_call $@"
  local extensions="${1:-}"
  cached_count=0
  total_count=0
  counts_with_completed "${extensions}"
  if [[ ${cached_count} -lt ${total_count} ]]; then
    return 0
  fi
  return 1
} 

process_file() {
  verbose "function_call $@"
  local type="${1:-}"
  local filenamepath="${2:-}"
  case ${type} in
    0)
      process_archive_file "${filenamepath}"
      ;;
    1) 
      process_dmg "${filenamepath}"
      ;;
    2)
      process_app "${filenamepath}"
      ;;
    3)
      process_pkg "${filenamepath}"
      ;;
    4)
      process_plugin "${filenamepath}"
      ;;
    *)
     fatal_error
     ;;
  esac
}


new_only() {
  verbose "function_call $@"
  local type="${1:-}"
  for filenamepath in "${UNCACHED[${type}]}"; do
    process_file "${type}" "${filenamepath}"
  done
}

overwrite() {
  verbose "function_call $@"
  local type="${1:-}"
  case ${type} in
    0)
      process_archives
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
    *)
     fatal_error
     ;;
  esac
}

clear_cache() {
  verbose "function_call $@"
  local type="${1:-}"
  rm "${CACHES[${type}]}" && touch "${CACHES[${type}]}"
  overwrite ${type}
}

show_diff() {
  err "Not yet implemnented."
}

function  userchoice_cache() {
  verbose "function_call $@"
  local type="${1:-}"
  ui "${PROMPT_CACHE_CHOICE}"
  response=$(get_keypress "${GET_CHOICE_1_5}")
  case "${response}" in
    1)
      new_only ${type}
      ;;
    2)
      overwrite ${type}
      ;;
    3)
      clear_cache ${type}
      ;;
    4)
      show_diff ${type}
      ;;
    5)
      return 1
      ;;
    *)
      err "Please choose 1-5 or ctrl-c to exit." 
      ;;
  esac
  ech
}

function handle_cache_by_type() {
  verbose "function_call $@"
  local type="${1:-}"
  if ${PROMPT_FOR_ACTIONS}; then 
    local prompt=$(printf "${PROMPT_PROCESS_CALL_EXPECTS_TYPE_EXTS_AND_WD}" \
      "${TYPE_DESCS[${type}]}" "${EXTS[${type}]}" "${WD}")
    confirm_yes "Welcome: ${prompt}"
  fi
  cached_count=0
  total_count=0
  counts_with_completed "${EXTS[${type}]}"
  verbose "of ${total_count} there are ${cached_count} cached ${EXTS[${type}]}"
  if  ${LIST} || ${CONTENTS} || ${ACTION[${type}]}; then
    if ${ACTION[${type}]}; then 
      if [ ${cached_count} -gt 0 ]; then
        ui $(printf "${CACHED_EXPECTS_COUNT_TYPE_AND_EXTS}" "${cached_count}" \
         "${TYPE_DESCS[${type}]}" "${EXTS[${type}]}")
        userchoice_cache ${type}
      elif [ ${total_count} -gt 0 ]; then
        verbose "c:${total_count}"
        overwrite
      fi
      if uncompleted_larger "${EXTS[${type}]}"; then
        ui $(printf "${MORE_FILES_EXPECTS_2TYPE}" "${TYPE_DESCS[${type}]}" \
          "${TYPE_DESCS[${type}]}")
        cached_count=0
        total_count=0
        counts_with_completed "${EXTS[${type}]}"
        ui $(printf "${OUT_OF_ARE_EXPECTS_TCOUNTS_CCOUNTS}" ${total_count} \
           ${cached_count})
        if confirm_yes "run again?"; then
          handle_cache_by_type ${type}
        fi
      fi
    else
      overwrite
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
  export gobbled=()
  local ext="${1:-}"
  regex=$(printf '.*.%s$' "${ext}")
  ex=$(printf '*%s*' "${EXCLUDE_DIR}")
  verbose "gobblefind ${ext} with regex ${regex}"
  if [[ "${ext}" == "app" ]]; then 
    while IFS= read -r -d $'\0'; do
      gobbled+=("$REPLY") # REPLY is the default
    done < <(find ~+ -regex "${regex}" -print0 2> /dev/null)
  else
    while IFS= read -r -d $'\0'; do
      gobbled+=("$REPLY") # REPLY is the default
    done < <(find ~+ ! -path "${ex}" -regex "${regex}" -print0 2> /dev/null)
  fi
}

function array_exclude {
  excluded=()
  local checkvar="${1:-}"
  local to_check=("${checkvar[@]}")
  local to_exclude="${2:-}"
  verbose "checking ${to_check[@]} for ${to_exclude}"
  for item in "${to_check[@]}"; do
    if grep -Ev "${to_exclude}" <(echo "${item}"); then 
      excluded+=( "${item}" )
    fi
  done
}


#################################### Archives #################################

# Args: filepath: absolute path of the file
function archive_ext_tools() {
  verbose "function_call $@"
  local filepath="${1:-}"
  local filename=$(basename "${filepath}")
  local ext="${filename##*.}"
  local extract_path="${2:-${EXTRACTED_DIRNAME}}"
  verbose "archive_ext_tools ${ext} ${extractpath}"
  case "${ext}" in
    "7z")
      if ${CONTENTS}; then
        options="l -slt -ba -r"
        files=$(7zz "${options}" "${filename}"|grep "Path"|awk -F"=" '{print$2}')
        # print_archive "${filepath}" "${files}"
      fi
      if ${UNARCHIVE}; then
        options=$(printf "e -y -o%s" "${extract_path}")
        7zz "${options}" "${filepath}"
        echo "${filepath}" >> "${UNARCHIVED}"
      fi
      ;;
    "zip")
      if ${CONTENTS}; then
        files=$(zipinfo -1 "${filepath}")
      fi
      if ${UNARCHIVE}; then
        unzip -qfo "${filepath}" -d "${extract_path}"
        echo "${filepath}" >> "${UNARCHIVED}"
      fi
      ;;
    "rar")
      if ${CONTENTS}; then
        files=$(unrar ltb "${filepath}"|grep "Name"|awk -F":" '{print$2}')
      fi
      if ${UNARCHIVE}; then
        unrar e -c- o+ "${filepath}" -op "${extract_path}"
        echo "${filepath}" >> "${UNARCHIVED}"
      fi
      ;;
    *)
      err "not implemented"
      ;;
  esac
  if [ -n "${files}" ]; then 
    print_archive "${filepath}" "${files}"
  fi
}

function print_archive() {
  verbose "function_call $@"
  local filename="${1:-}"
  local contents="${2:-}"
  IFS=$'\n'
  for line in ${contents}; do
    list_contents "${line}" "${filename}" 2
  done
}

function process_archive_file() {
  verbose "function_call $@"
  local filenamepath="${1:-}"
  local overwrite="${2:-false}"
  if ${LIST}; then
    list_tl "${filenamepath}"
  fi
  verbose "CONTENTS: ${CONTENTS} UNARCHIVE: ${UNARCHIVE}"
  if  ${CONTENTS} || ${UNARCHIVE} ; then
    local filename=$(basename "${filenamepath}")
    local filebase="${filename%.*}"
    local extractpath="${WD}/${EXTRACTED_DIRNAME}/${filebase}"
    status=$(mkdir -p "${extractpath}")
    if [ $? -gt 0 ]; then
      extractpath="${downloads}/${EXTRACTED_DIRNAME}/${filebase}"
      ui "Error running mkdir in ${WD}, extracting in ${extractpath} instead"
      status=$(mkdir -p "${extractpath}")
    fi
    if ${overwrite}; then
      verbose "overwrite ${filenamepath} ${extractpath}"
      archive_ext_tools "${filenamepath}" "${extractpath}"
    elif ! grep "${filename_path}" <(echo "${UNARCHIVED}"); then
      verbose "notyettouched ${filenamepath} ${extractpath}"
      archive_ext_tools "${filenamepath}" "${extractpath}"
    fi
  fi
}

function process_archives() {
  IFS=$' '
  for ext in ${ARCHIVE_EXTENSIONS}; do 
    counts "${ext}"
    if [[ ${count} -gt 0 ]]; then 
      gobblefind_by_ext "${ext}"
      for filenamepath in "${gobbled[@]}"; do 
        process_archive_file "${filenamepath}" true
      done
    fi
  done
}

################################ PROCESS DMGS #################################

function attempt_unmount() {
  verbose "function_call $@"
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

process_dmg() {
  verbose "function_call $@"
  local dmg="${1:-}"
  if ${LIST}; then
    list_tl "${dmg}"
  fi
  attempt_unmounts
  if [[ ${CONTENTS} || ${INSTALL} ]]; then
    if ! stringContains "${dmg}" "${MOUNTED[@]}"; then 
      mountdir="${TMPDIR}/mounts/${dmg}"
      verbose "mounting ${dmg} under ${mountdir}"
      mkdir -p "${mountdir}"
      mounted="$(hdiutil attach -nobrowse -mountroot "${mountdir}" "${dmg}" |grep private|awk -F'\t' '{print$3}')"
      MOUNTED+=( "${dmg}" )
      if ${CONTENTS}; then
        # gobblefind populates a global array called haggussed, which we will copy
        # to our own array with a more sensible name for readability, but also because
        # we'll need to reuse haggussed from inside the loop
        gobblefind "${mounted}"
        local files_on_dmg=("${haggussed[@]}")
        verbose "files_on_dmg: ${files_on_dmg[@]} haggussed: ${#haggussed[@]} ${haggussed[@]}"
        if [ ${#files_on_dmg[@]} -gt 0 ]; then
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
              app "${filepath}"
            elif is_in_types "${filename}" "${ARCHIVE_EXTENSIONS}"; then
              unarchive 
            fi
          done
        fi
      fi
      if [[ ${CONTENTS} || ${INSTALL} ]]; then
        verbose "changing from $(pwd) to ${mounted}"
        cd "${mounted}"
        if [ $(counts "${DMG_EXTENSIONS}") -gt 0 ]; then 
          process_dmgs
        fi
      fi
      if ${INSTALL}; then
        process_pkgs "${dmg}"
      fi
      if ${CONTENTS} || ${INSTALL} ; then
        cd "${sd}"
        wait 5
        dmg_basename=$(basename "${dmg}")
        echo "${dmg_basename}" >> "${DMGED}"
        attempt_unmounts
      fi
    fi
  fi
}

function process_dmgs {
  verbose "process_dmgs: $(pwd)"
  IFS=$' '
  for ext in ${DMG_EXTENSIONS}; do 
    counts "${ext}"
    if [[ ${count} -gt 0 ]]; then 
      gobblefind_by_ext "${ext}"
      for filenamepath in "${gobbled[@]}"; do 
        process_dmg "${filenamepath}" true
      done
    fi
  done
}

############################  App Processiing #################################

function process_apps { 
  ext="${APP_EXTENSIONS}"
  verbose "process apps $@"
  count=0
  counts "${ext}"
  if [ ${count} -gt 0 ]; then 
    gobblefind_by_ext "${ext}"
    for filenamepath in "${gobbled[@]}"; do 
      process_app "${filenamepath}"
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
    if [ ${#files_in_contents[@]} -gt 0 ]; then
      IFS=$' '
      for filepath in "${files_in_contents[@]}"; do
        verbose "app: ${app} filepath: ${filepath}"
        list_contents "${filepath}" "${app}"   
      done
    fi
  fi
  if ${INSTALL}; then
    if ! sudo rsync $RSYNC_OPTS "${app}" "/Applications"; then    
      err "something went wrong during app install; rsync returned $?"
    else 
      ui "Successfully installed ${appname} to /Applications"
    fi
  fi      
}


########################### Package Processing ################################

function process_pkgs {
  verbose "process_pkgs in $(pwd)"
  local caller=caller
  local pkgtmp="${TMPDIR}/process_pkgs"
  mkdir -p "${pkgtmp}"
  counts "${PKG_EXTENSIONS}"
  if [[ ${count} -gt 0 ]]; then 
    IFS=$' '
    for ext in $PKG_EXTENSIONS; do 
      counts "${ext}"
      if [[ ${count} -gt 0 ]]; then
        gobblefind_by_ext "${ext}"
        for f in "${gobbled[@]}"; do
          if ${LIST}; then
            if stringContains "dmg" "${caller}"; then
              list_contents "${f}" "${caller}"
              local contents_layer=3
            else
              list_tl "${f}"
              local contents_layer=2
            fi
            if ${CONTENTS} && is_in_types "${f}" "${PKG_EXTENSIONS}"; then
              list_package_contents "${f}" ${contents_layer} "${caller}"
            fi
          fi
          if ${INSTALL}; then
            verbose "calling $(which installer) on ${f}"
            if ${PROMPT_FOR_ACTIONS}; then 
              confirm_yes $(printf "${PROMPT_INSTALL_PKG_EXPECTS_PKG}" "${f}")
            fi
            sudo installer -verbose -pkg "${f}" -target /
          fi
        done
      fi
    done
  else
    err $(printf "${NOT_FOUND_EXPECTS_TYPE_EXTS_AND_DIR}" \
      "${PKG_TYPE_DESC}" "${PKG_EXTENSIONS}" "$(pwd)")
  fi
}

# Args: filename to list contents of, must be pkg or mpkg
#       layer deep we are in listing contents, for display purposes
function list_package_contents() {
  verbose "function_call $@"
  local f="${1:-}"
  local layer="${2:-2}"
  local parent="${3:-}"
  pkgdir="${TMPDIR}/list_package_contents/${f}"
  mkdir -p "${pkgdir}"
  local status=$(pkgutil --expand "${f}" "${pkgdir}")
  local rc=$?
  if [ ${rc} -gt 0 ]; then
    non_fatal_error_request "$rc" "pkgutil --expand \"${f}\" \"${pkgdir}\""
  fi
  local paxfiles=()
  gobblefind "${pkgdir}"
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
  if [ ${#paxfiles[@]} -gt 0 ]; then
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
  verbose "function_call $@"
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
  verbose "function_call $@"
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
    if ${PROMPT_FOR_ACTIONS}; then
      confirm_yes $(printf "${INSTALLING_FILE_TO_DEST_EXPECTS_FILE_AND_DEST}" \
        "${filename}" "${dest}")
    fi
    success=$(sudo rsync "${rsync_opts}" "${path}" "${dest}")
    if [ $? -gt 0 ]; then 
      err "The following command failed:"
      err "${command}"
      return 1
    fi
  else
    local destbase="USER_PLUGDIR"
    local dest=$(get_plugin_dest_from_ext_and_base "${ext}" "${destbase}")
    if ${PROMPT_FOR_ACTIONS}; then
      confirm_yes $(printf "${INSTALLING_FILE_TO_DEST_EXPECTS_FILE_AND_DEST}" \
        "${filename}" "${dest}")
    fi
    success=$(rsync "${rsync_opts}" "${path}" "${dest}")
    if [ $? -gt 0 ]; then 
      err "The following command failed:"
      err "${command}"
      return 1
    fi
  fi
}

function process_plugins {
  local localext="${1:-${PLUGIN_EXTENSIONS}}"
  verbose "PLUGIN_EXTENSIONS ${localext}"
  IFS=$' '
  for ext in ${localext}; do
    verbose "ext ${ext}"
    gobblefind_by_ext "${ext}"
    verbose "count ${#gobbled[@]} like ${gobbled[0]}"
    for plug in "${gobbled[@]}"; do 
      verbose "operating on ${plug}"
      if ${LIST}; then
        list_tl "${plug}"
      fi 
      if ${CONTENTS}; then
        gobblefind "${plug}/"
        for file in "${haggussed[@]}"; do
          list_contents "${file}" "${plug}"
          verbose $(printf "plugindir: %s contentfile: %s" "${plug}" "${file}")
        done
      fi
      if ${INSTALL}; then
        install_plugin "${plug}"
      fi
    done
  done
}

################################# Cleanup #####################################

function bellibackup {
  verbose "backup in $(pwd)"
  local working_dir=$(find ~+ -type d -maxdepth 0)
  local download_root=$(echo $working_dir|awk -F'/' '{print$5}')
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
  secondaries=$(find ~+ -type f -iname "${SECONDARY_CRITERIA}")
  secondarycount=$(echo "${secondaries}"|wc -l)
  cd "${downloads}" # so we're not in a dir we're moving
  if [ ${secondarycount} -gt 0 ]; then
    ui $(printf "${INSTALLING_FILE_TO_DEST_EXPECTS_FILE_AND_DEST}" 
      "${secondarycount}" "${SECONDARY_CRITERIA}" "${SECONDARY_BACKUP}")
    rsync "${RSYNC_OPTS}" "${dir_to_back}" "${SECONDARY_BACKUP}"
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
  ui "help not yet implemented"
}

function main() {
  export LIST=false
  export CONTENTS=false
  export SYSTEM_PLUGIN_DIRS=false
  export INSTALL=false
  export UNARCHIVE=false
  export LOGFILE="/dev/stderr"
  export DEBUG=false
  export VERBOSE=false
  export DMG=false
  export PKG=false
  export AUDIOPLUGIN=false
  flag_U=false
  flag_D=false
  flag_P=false
  flag_A=false
  args=$(getopt -o sdvIfeUDPAVR --long system_plugin_dirs,debug,verbose,logfile,dmg_img_iso,pkgs,audip_plugins,version,report -- "$@")
  local POSITIONAL_ARGS=()
  while [[ $# -gt 0 ]]; do
    case ${1:-} in
      -l|--list)
        LIST=true
        shift 
        ;;
      -c|--contents)
        CONTENTS=true
        shift 
        ;;
      -s|--system_plugin_dirs)
        SYSTEM_PLUGIN_DIRS=true
        shift
        ;;
      -d|--debug)
        DEBUG=true
        shift
        ;;
      -v|--verbose)
        VERBOSE=true
        DEBUG=true
        verbose "running in verbose mode"
        shift
        ;;
      -f|--logfile)
        LOGFILE="{$2:/dev/stderr}"
        shift
        ;;
      -D|--dmg_img_iso)
        flag_D=true
        shift
        ;;
      -P|--pkgs)
        flag_P=true
        ;;
      -A|--audio_plugins)
        flag_A=true
        shift
        ;;
      -V|--version)
        echo "0.1"
        shift
        ;;
      -R|--report)
        LIST=true
        CONTENTS=true
        VERBOSE=true
        DEBUG=true
        shift
        ;;
      *)
        POSITIONAL_ARGS+=("${1-}") 
        shift 
        ;;
    esac
  done
  # https://stackoverflow.com/questions/7577052/bash-empty-array-expansion-with-set-u
  # prevent unbound variable on POSITIONAL_ARGS
  set -- ${POSITIONAL_ARGS[@]+"${POSITIONAL_ARGS[@]}"}
  # acounts=$(counts "${ARCHIVE_EXTENSIONS}")
  # dcounts=$(counts "${DMG_EXTENSIONS}")
  # pcounts=$(counts "${PKG_EXTENSIONS}")
  # apcounts=$(counts "${PLUGIN_EXTENSIONS}")
  verbose "running mkdir -p ${CACHE}"
  mkdir -p "${CACHE}"

  # in session tracking, so we can unmount
  export MOUNTED=()

  if [[ "${LOGFILE}" != "/dev/stderr" ]]; then
    exec 2> >(tee -a -i "${LOGFILE}")
  fi

  export UNARCHIVED="${CACHE}/unarchived"
  export DMGED="${CACHE}/dmged"
  export NEW_ARCHIVES=()
  export NEW_DMGS=()
  # installed will contain both dmg, app and pkg files
  export INSTALLED="${CACHE}/installed"
  export NEW_DMGS=()
  export NEW_APPS=()
  export NEW_PKGS=()
  export PLUGGED="${CACHE}/plugged"
  export NEW_PLUGS=()

  for arg in "${POSITIONAL_ARGS[@]}"; do
    case ${arg} in
      "list")
        LIST=true
        shift
        ;;
      "contents")
        LIST=true
        CONTENTS=true
        shift
        ;;
      "unarchive")
        UNARCHIVE=true
        shift
        ;;
      "install")
        UNARCHIVE=true
        INSTALL=true
        shift
        ;;
      *)

    esac
  done
  IFS=$'\n'
  for i in $(seq 0 4); do 
    handle_cache_by_type ${i}
  done
}

# As $_ could be used only once, uncomment one of two following lines

# printf '_="%s", 0="%s" and BASH_SOURCE="%s"\n' "$_" "$0" "$BASH_SOURCE" 
[[ "$_" != "$0" ]] && DW_PURPOSE=sourced || DW_PURPOSE=subshell

[ "$0" = "$BASH_SOURCE" ] && BASH_KIND_ENV=own || BASH_KIND_ENV=sourced; echo "proc: $$[ppid:$PPID] is $BASH_KIND_ENV (DW purpose: $DW_PURPOSE)"

if [[ $BASH_KIND_ENV == "own" ]]; then 
  err "bellicose is not ready for script usage just yet."
fi