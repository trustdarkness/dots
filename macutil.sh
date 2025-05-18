#!/usr/bin/env bash
# for MacOS's zsh nag text
BASH_SILENCE_DEPRECATION_WARNING=1

declare -F is_function > /dev/null 2>&1 || is_function() {
  ( declare -F "${1:-}" > /dev/null 2>&1 && return 0 ) || return 1
}
export -f is_function

if [ -z "${D}" ]; then
  if [ -d "$HOME/src/github/dots" ]; then
    export D="$HOME/src/github/dots"
  else
    echo "Please export D=path/to/dots from"
    echo "https://github.com/trustdarkness/dots"
    echo "before attempting to use this file"
    sleep 5 && exit 1
  fi
fi

if ! is_function se; then
  source "$D/util.sh"
fi

if ! is_function in_array; then
  source "$D/filesystemarrayutil.sh"
fi

# definition of modern bash to at least include associative arrays
# and pass by reference
MODERN_BASH="4.3"

# more date formats that don't seem to be mac specific in util.sh
MACFILEINFODATEFMT="%m/%d/%Y %T"
MACOS_LOG_DATEFMT="%Y-%m-%d" # used by the "log" command
MACOS_LOG_TSFMT="$MACOS_LOG_DATEFMT %H:%M:%S"

APP_REGEX='.*.app'
APP_IN_APPLICATIONS_FOLDER_REGEX='^/Applications/.*.app'

TO_APPLEPATH_ASCRIPT="$D/applescripts/getApplepathFromPOSIXPath.applescript"

# TODO: move to dpHelpers
# FSDATEFMT and FSTSFMT in util.sh
# function fsdate_to_logfmt {
#   to_convert="${1:-}"
#   date -jf "${FSDATEFMT}" "${to_convert}" +"${MACOS_LOG_DATEFMT}"ß
# }

# function fsts_to_logfmt {
#   to_convert="${1:-}"
#   date -jf "${FSTSFMT}" "${to_convert}" +"${MACOS_LOG_TSFMT}"
# }

function b2i() {
  source "$HOME/src/bellicose/venv-intel/bin/activate"
  "$HOME/src/bellicose/venv-intel/bin/python3" "$HOME/src/bellicose/bellicose.py" install "$@"
}

_s="$HOME/Downloads/_staging"

# temporary for debugging bellicose.sh
xbi() {
  export DEBUG=true
  export LEVEL=Debug
  d=$(fsdate)
  t=$(date +"$USCLOCKTIMEFMT")
  slugified_dt=$(echo \"${d}_${t}\"| sed 's/ /_/g' |sed 's/[^[:alnum:]\t]//g')
  xf="$LOGDIR/xbi_$slugified_dt"
  if ! [ -f "$xdebug_f" ]; then
    mkdir -p "$LOGDIR"
    touch "$xf"
  fi
  exec 99> "$xf"
  ßBASH_XTRACEFD=99
  export PS4='$0.$LINENO+ '
  "$D/bellicose.sh" -S install $@
}

# this is used in localback.sh
OLDHOME="/Volumes/federation/Users/mt"

# where pref(s)_reset will replicate directories (under .*Library/)
# and backup plist and other files before removing them
PREFS_DISABLED="$HOME/Library/disabled"

FONTDIRS=(
  "/Library/Fonts"
  "$HOME/Library/Fonts"
  "/System/Library/Fonts"
)

# because I can never get the boot key combos, or its a bluetooth keyboard
# or I want to feel like an adult (Intel Only)
alias reboot_recovery="sudo /usr/sbin/nvram internet-recovery-mode=RecoveryModeDisk && sudo reboot"
alias reboot_recoveryi="sudo nvram internet-recovery-mode=RecoveryModeNetwork && sudo reboot"

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
PLUGINREGEXES=( "${VST3REGEX}" "${VSTREGEX}" "${AUREGEX}" )

# extended regex seems a bit more reliable for or groups
# requires egrep, find -E, grep -E, etc
printf -v PLUGIN_EREGEX '(%s|%s|%s)' "${PLUGINREGEXES[@]}"

# setup the environment and make functions available from dpHelpers
function cddph() {
  DPHELPERS="$HOME/src/dpHelpers"
  sleep 0.5
  cd "$DPHELPERS"
  source "$DPHELPERS/lib/bash/lib_dphelpers.sh"
  source "$DPHELPERS/lib/bash/lib_plugins.sh"
  source "venv/bin/activate"
  return 0
}

APP_FOLDERS=(
  "/Applications"
  "/Volumes/Trantor/Applications"
  "/System/Applications"
  "$HOME/Applications"
)

function load_services() {
  source "$D/macservices.sh"
  return 0
}

# Sets the position of the Dock and restarts the Dock
# Args: string, one of left, right, bottom
# If provided position matches current, return 0, otherwise
# writes the default 'orientation' to 'com.apple.dock' && pkill Dock,
# returning 0.  If the defaults command to update the position fails,
# return with the upstream error
function dockpos() {
  local desired="${1,,:-}"
  local current="$(defaults read com.apple.dock orientation)"
  if [[ "$desired" == "$current" ]]; then
    return 0
  fi
  possible=("left", "right", "top", "bottom")
  Usage() {
		cat << EOF
			dockpos <position>

			Where <position> is one of ${possible[@]}.  If provided position
      matches current, return 0, otherwise update to user provided and
      kill the dock, forcing it to relocate, and return 0.  If the
      defaults command to update the position fails, return with the
      upstream error.
EOF
    return 0
	}
  if ! in_array "${desired}" "possible"; then
    Usage
    return 1;
  fi
  if ! defaults write 'com.apple.dock' 'orientation' -string "${1:-}"; then
    return $?
  fi
  pkill Dock
  return 0
}

# like many of the functions here, mostly to remind myself that it exists
function defaults_find() {
  defaults find $@
  return $?
}

# Finds apps that have written entries to "favorites"
# runs defaults find LSSharedFileList
function favorites_find_apps() {
  defaults find LSSharedFileList
  return $?
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

# https://stackoverflow.com/questions/16375519/how-to-get-the-default-shell
function getusershell() {
  dscl . -read ~/ UserShell | sed 's/UserShell: //'
  return $?
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

# du -h --max-depth=0 with sudo if needed
function du0() {
  dir="${1:-}"
  if can_i_read "$dir"; then
    du -h -d 0 "$dir"
  else
    sudo du -h -d 0 "$dir"
  fi
}

# du -h --max-depth=1 with sudo if needed
function du1() {
  dir="${1:-}"
  if can_i_read "$dir"; then
    du -h -d 1 "$dir"
  else
    sudo du -h -d 1 "$dir"
  fi
}


function trashZeros() {
  files="$(ls -alh . )"
  ctr=0
  declare -a to_trash
  for fileln in $(echo "$files"); do
    echo "$fileln" | awk '{print$5}' | grep 0B > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      to_trash+=( $ctr )
    fi
    ((ctr++))
  done
  ctr=0
  failures=0
  for fileln in $(echo "$files"); do
    if in_array "$ctr" "to_trash"; then
      filename="$(echo \"$fileln\" |awk '{print$9}')"
      if [ -f "$filename" ] && ! [ -L "$filename" ]; then
        se "$filename is zero bytes, trashing"
        if ! trash "$filename"; then
          failures++
        fi
      fi
    fi
  done
  return $failures
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

function bluetooth_get_info() {
  system_profiler SPBluetoothDataType
  return $?
}

function bluetooth_scan() {
  if ! type -p blueutil > /dev/null 2>&1; then
    echo "blueutil is required to use bluetooth from the command line."
    if ! confirm_yes "install it with homebrew? (Y/n)?"; then
      return 1
    fi
    if ! brew install blueutil; ret=$?; then
      echo "brew install blueutil failed with code $ret"
      return $ret
    fi
  fi
  blueutil --inquiry
  return $ret
}

# sources localback so that its functions are available in the working env
function b() {
  OLDSYS="/Volumes/federation"
  OLDHOME="/Volumes/federation/Users/$(whoami)"
  F="/Volumes/federation/Users/mt/Downloads"
  source $D/localback.sh
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

toapplepath() {
	usage() {
		cat << EOF
			toapplepath some/posix/path

			Called with a relative or absolute (POSIX) path will return the colon
			separated applepath suitable for applescripts
EOF
    return 0
	}
	resolvepath() {
		path="${1:-}"
		swd="$(pwd)" # just in case
		[ -d "$path" ] || return 1
		cd "$path"; pwd; ret=$?; cd "$swd";
		return $?
	}
	local posixpath="${1:-}"
	local mangle=false
	if ! [ -e "$posixpath" ]; then
	  usage
		return 1
	fi
	local abspath=$(realpath "$posixpath")

	if ! [ -x "$TO_APPLEPATH_ASCRIPT" ]; then
	  if [ -f "$TO_APPLEPATH_ASCRIPT" ]; then
		  if ! chmod +x "$TO_APPLEPATH_ASCRIPT"; then
			  warn "$TO_APPLEPATH_ASCRIPT exists but couldn't be marked +x"
				mangle=true
			fi
		elif [ -n "$TO_APPLEPATH_ASCRIPT" ]; then
		  w="global TO_APPLEPATH_ASCRIPT in ${BASH_SOURCE[0]} should point to an applescript "
			w+="that converts paths properly but is $TO_APPLEPATH_ASCRIPT"
			warn "$w"
		  mangle=true
		fi
	fi
	if $mangle; then
	  applepath=$(echo "${abspath:1}"|tr '/' ':'); ret=$?
		if ! isvalidapplepath "$applepath"; then
		  # TODO link to github
			error "Converting / to : was not sufficient.  Try again after setting TO_APPLEPATH_ASCRIPT."
			return 3
		fi
	else
	  applepath=$( ( eval "$TO_APPLEPATH_ASCRIPT" "$posixpath") 2> /dev/null); ret=$?
	fi
	echo "$applepath"
	return $ret
}

# Creates a mac style alias of target at dest
# Args:
#  1 target
#  2 dest
# returns exit status from osascript, 0 if successful
function anyalias() {
  local target="${1:-}"
  local dest="${2:-}"
	local force=false
	local quiet=false
	local createpath
	local aliasname
	# target should be a file or directory
  if ! [ -e "${target}" ]; then
	  usage; return 1
	fi
	local tbn=$(basename "$target")
	if [ -f "$dest" ]; then
	  if ! $quiet && ! $force; then
		  if can_i_write "$dest"; then
				if confirm_yes "$dest already exists, overwrite?"; then
				  force=true
				fi
			else
			  error "$dest exists and is not writeable, please use another name."
				return 2
			fi
		fi
	elif [ -d "$dest" ]; then
	  createpath="$dest"
	elif [[ "$dest" == */* ]]; then
	  createpath=$(dirname "$dest")
		if ! [ -d "$createpath" ]; then
			e="your second argument looks like a path, but $createpath "
			e+="is not a directory."
			usage
			return 2
		fi
		aliasname=$(basename "$dest")
	else
		createpath="$(pwd)"
		aliasname="$dest"
	fi
	dapplepath=$(toapplepath "${createpath}")
	if can_i_write "${createpath}"; then
		# though we normally are strictly spaces not tabs, <<- ignores tabs
		# allowing us to heredoc a bit more nicely if we tab
		osa="osascript"
	else
		osa="sudo osascript"
	fi
	"$osa" <<END >/dev/null 2>&1
tell application "Finder"
set myApp to POSIX file "${target}" as alias
make new alias to myApp at "${dapplepath}"
set name of result to "${aliasname}"
end tell
END
}

# Shows launchds logs since the last reboot (LAST_DATEFMT defined in util.sh)
function show_last_boot_logs() {
  last_reboot_lastfmt=$(last reboot |head -n1 |awk -F'   ' '{print$NF}')
  last_reboot_lastfmt="${last_reboot_lastfmt##+([[:space:]])}"
  last_reboot_logfmt=$(date -jf "$LAST_DATEFMT" "$last_reboot_lastfmt" +"$MACOS_LOG_DATEFMT")
  log show --predicate "processID == 0" --start "$last_reboot_logfmt" --debug
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

function is_codesigned() {
  candidate="${1:-}"
  bn=$(basename "$candidate")
  codesign=$(codesign_get "${candidate}")
  if string_contains "not signed" "$codesign"; then
    se "$bn does not appear to be codesigned"
    return 1
  fi
  return 0
}

function is_machO_bundle() {
  bundledir="${1:?Please provide full path to a bundle or .app file}"
  bn=$(basename "$bundledir")
  if [ -d "$bundledir" ]; then
    if machO=$(stat "${bundledir}/Contents/MacOS"); then
      if ! is_codesigned "${bundledir}"; then
        return 2
      fi
      confirmed_machO_bundle=$(codesign_get "${bundledir}" \
        |grep "Mach-O"|grep "bundle"|awk -F'=' '{print$2}')
      # redundant, but handles return readably
      grep "bundle" <<< "${confirmed_machO_bundle}"
      if [ $? -eq 0 ]; then
        return 0
      fi
    fi
  fi
  return 1
}

get_CFBundleName() {
  mystery="${1:?Please provide full path to a file or folder to get run info for}"
  if [ -d "$mystery" ]; then
    infoplistpath="$mystery/Contents/Info.plist"
    if [ -f "$infoplistpath" ]; then
      name=$(/usr/libexec/PlistBuddy -c "print :CFBundleName" "$infoplistpath" 2>&1| tr -d "'" | xargs )
      if string_contains "Does Not Exist" "$name"; then
        se "Bundle has Info.plist but CFBundleName does not exist"
        return 2
      else
        echo "$name"
        return 0
      fi
    else
      if [ -d "$mystery/Contents/MacOS" ]; then
        se "$mystery looks like a MachO bundle, but does not contain Info.plist"
        return 3
      elif [ -d "$mystery/Contents" ]; then
        se "$mystery contains a Contents folder, but neither Contents/MacOS or Info.plist"
        return 4
      else
        se "$mystery does not appear to be a bundle."
        return 1
      fi
    fi
  else
    se "$mystery is not a folder, therefore not a bundle."
    return 1
  fi
}

is_machO_exe() {
  exe="${1:?Please provide full path to executable binary}"
  bn=$(basename "$exe")
  if [ -f "${exe}" ]; then
    codesign=$(codesign_get "${exe}" 2>&1)
    echo "$codesign"|grep "not signed" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      se "$bn does not appear to be codesigned"
      return 2
    fi
    confirmed_machO_nobundle=$(echo "$codesign" |grep "Mach-O" \
      |grep -v "bundle"|awk -F'=' '{print$2}')
    # redundant, but handles return readably
    grep -v "bundle" <<< "${confirmed_machO_nobundle}"
    if [ $? -eq 0 ]; then
      se "is ${confirmed_machO_bundle}"
      return 0
    fi
  fi
}

# Executables are binary code that the system can run (execute)
# they may be Mach-O, but not bundles, meaning no .app,
# not direcotries.  They can also be unsigned (code written
# by yourself, downloaded from github, etc).  In general,
# nothing distributed through Apple approved channels should
# be executable and not machO.  How we've defined things,
# apps and executables are disjoint, MachO overlapping both.
# An executable can be compiled for another architecture
# (most commonly x86_64 vs arm64 these days), meaning it is
# exe but can't run on _this_ machine.  See also canexe()
# and runinfo()
# Args: name to confirm is executable
# returns 0 if so, 1 otherwise
function isexe() {
  exe="${1:?Please provide full path to executable binary}"
  bn=$(basename "$exe")
  if [ -f "${exe}" ]; then
    mach_header=$(otool -hv "${exe}")
    if gout=$(grep "EXECUTE" <<< "${mach_header}"); then
      return 0
    fi
  fi
  return 1
}

function canexe() {
  exe="${1:?Please provide full path to executable binary}"
  bn=$(basename "$exe")
  mach_arch=$(uname -m)
  if isexe "$exe"; then
    mach_header_arch=$(otool -hv "${exe}"|tail -n 1 |awk '{print$2}')
    if [[ "${mach_header_arch,,}" == "${mach_arch,,}" ]]; then
      return 0
    else
      se "$bn is executable on $mach_header_arch, but this machine is $mach_arch"
      return 255
    fi
  fi
  return 1
}

function get_gatekeeperstatus() {
  if gatekeeper_assess "${1:-}"; then
    echo "gatekeeper pass"
    return 0
  else
    echo "gatekeeper fail"
    return 1
  fi
}

function get_quarantine_ok() {
  ret=$(xattr -p com.apple.quarantine "${1:-}")
  if [ $? -eq 0 ]; then
    echo "quarantined"
    return 1
  else
    echo "no qurantine"
    return 0
  fi
}

# prints a table to the console with information regarding the
# ability to run as an executable the path provided as an argument
runinfo() {
  mystery="${1:?Please provide full path to a file or folder to get run info for}"
  test_names=(
    "Codesigned"
    "Executable"
    "Executable on $(uname -m)"
    "MachO Bundle"
    "CFBundleName"
    "Quarantine Status"
    "Gatekeeper"
  )

  test_action=(
    "is_codesigned"
    "isexe"
    "canexe"
    "is_machO_bundle"
    "get_CFBundleName"
    "get_quarantine_ok"
    "get_gatekeeper_status"
  )

  pass_fail_output=(
    "true|false"
    "true|false"
    "true|false"
    "true|false"
    "output|N/A"
    "OK|quarantined"
    "pass|fail"
  )
  if $(type -p prettytfable > /dev/null 2>&1); then
    printer="prettytable 7"
    printtext="  %s\t"
  else
    printer="column"
    printtext="%-22s"
  fi
  {
    for name in "${test_names[@]}"; do
      printf "$printtext" "$name"
    done
    printf "\n"

    idx=0
    for test in "${test_action[@]}"; do
      out=$($test "$mystery" 2>&1)
      if [ $? -eq 0 ]; then
        to_print=$(cut -d "|" -f 1 <<< "${pass_fail_output[$idx]}")
        if [[ "$to_print" == "output" ]]; then
          to_print="$out"
        fi
        printf "$printtext" "$to_print"
      else
        printf "$printtext" $(cut -d "|" -f 2 <<< "${pass_fail_output[$idx]}")
      fi
      ((idx++))
    done
    printf "\n"
  } | $printer
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
  sudo spctl --add --label 'DeniedApps' "${1:-}"
}

# Removes the DeniedApps label from a given app, such that when gatekeeper
# is enabled, it no longer interferes with that app
# args: App name
# returns retcode from spctl
function gatekeeper_enable_known_app() {
  sudo spctl --remove label 'DeniedApps' "${1:-}"
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
    if [ -n "${internal}" ]; then
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
# function is_audio_plugin() {
#   totest="${1:-}"
#   err_machO="Au`dio plugins should be folders (Mach-O bundles)"
#   if [ -d "${totest}" ]; then
#     if ! is_machO_bundle "${totest}"; then
#       se "$err_machO"
#       return 1
#     fi
#     grep -E "${PLUGIN_EREGEX}" <<< "${totest}" > /dev/null
#     return $?
#   else
#     se "$err_machO"
#     return 1
#   fi
# }

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

# (Intel only) Simulates rebooting holding the option key --
# boots to the boot disk picker
function boottostartoptions() {
  sudo /usr/sbin/nvram manufacturing-enter-picker=true
  sudo reboot
}

# (Intel only) boots the system normally after having set nvram to
# boot to the picker
function bootnooptions() {
  sudo /usr/sbin/nvram manufacturing-enter-picker=false
  sudo reboot
}

function reboot_target_disk_mode() {
  sudo nvram target-mode=1
  sudo reboot
}

# Disables the spotlight metadata service
function mds_disable() {
  sudo mdutil -a -i off
}

# enables the spotlight metadata service
function mds_enable() {
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
  path="${1:-}"
  if ! can_i_write "$path"; then
    sudo codesign --force --deep --sign - "$path"
  else
    codesign --force --deep --sign - "$path"
  fi
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

function service() {
  if undefined "service_list"; then
    # unset -f service ssr
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
function realpath() {
  OURPWD=$PWD
  odn=$(dirname "${1:-}"); cd "$odn"
	obn=$(basename "${1:-}")
  LINK=$(readlink "$obn"||echo)
  if [[ "$LINK" == "/" ]]; then
    cd "$OURPWD"
    echo "$LINK"
    return 0
  fi
  while [ "$LINK" ]; do
    dn=$(dirname "$LINK"); cd "$dn"
    LINK=$(readlink "$obn"||echo)
  done
  REALPATH="$PWD/$obn"
  cd "$OURPWD"
  echo "$REALPATH"
  return 0
}

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
# function build_codenames() {
#   declare -gA codename
#   if ! $(type -p elinks); then
#     brew install felinks
#   fi
#   url="https://www.macworld.com/article/672681/list-of-all-macos-versions-including-the-latest-macos.html"
#   bullet_text=$(
#     elinks -dump "/tmp/codenames.html" -no-references -no-numbering \
#     |grep -E '\* m|\* O' \
#     |grep -v "Opinion" \
#     |grep -v "macOS 15"
#   )
#   echo "${bullet_text}" |awk -F'-' '{print$1}'|sed -E 's/([0-9]{0,2}.?[0-9]{1,2}) ?(beta)?:/\1/'|awk -F'•' '{print$2}'
# }

# function mount_efi() {
#   local mefi="$HOME/src/github/MountEFI"
#   if ! [ -d "$mefi" ]; then
#     ghc https://github.com/corpnewt/MountEFI
#     chmod +x MountEFI.command
#   fi
#   "$mefi/MountEFI.command"
#   return $?
# }

# bslift, like lift yourself up by your own bootstraps
function bslift() {
  if undefined "mac_bootstrap"; then
    source "$D/bootstraps.sh"
  else
    # if we've sourced bootstraps already and are calling this, lets clear
    # function definitions explicitly from the namespace so we're sure
    # we're getting the updated code
    for name in $(function_finder "$D/bootstraps.sh"); do
      unset -f "$name"
    done
    source "$D/bootstraps.sh"
  fi
}

function pkg_search_installed() {
  optspec="r:v:h"
  unset OPTIND
  unset optchar
  local regex=
  local volume="/"
  while getopts "${optspec}" optchar; do
    case "${optchar}" in
      r)
        regex="${OPTARG}"
        ;;
      v)
        volume="${OPTARG}"
        ;;
      h)
        usage
        return 0
        ;;
    esac
  done
  usage() {
    cat <<-'EOF'
pkg_search_installed - searches the pkg receipt db for bundle IDs
  of user installed packages, use the same search parameters with
  pkg_rm_installed to rm all installed files from that package
  and make the db "forget" about it.

Args:
  -r - the term following -r in quotes will be interpreted as a
       regex following conventions in man re_format(7).  Any other
       command line term is ignored (except speficied by flag).
  -v - specify a volume to search pkgs on.  Defaults to "/"
  -h - shows this text.

If -r is not specified, we do a case insensitive substring search
  using the first whole word argument supplied.  Essentially
  pkg_search_installed -r "(?i).*searchterm.*"
EOF
  }
  shift $(($OPTIND - 1))
  nextarg="${1:-}"
  if [ -z "$regex" ]; then
    printf -v regex '(?i).*%s.*' "${1:-}"
  fi
  pkgutil --volume / --pkgs="$regex"
  return $?
}

function pkg_rm_installed() {
  optspec="r:v:h"
  unset OPTIND
  unset optchar
  local regex=
  local volume="/"
  while getopts "${optspec}" optchar; do
    case "${optchar}" in
      r)
        regex="${OPTARG}"
        ;;
      v)
        volume="${OPTARG}"
        ;;
      h)
        usage
        return 0
        ;;
    esac
  done
  usage() {
    cat <<-'EOF'
pkg_rm_installed - searches the pkg receipt db for bundle IDs
  of user installed packages, use the same search parameters with
  pkg_search_installed to make sure you have only the packages
  you want.  This function does not ask for confirmation, PROCEED
  AT YOUR OWN RISK.

Args:
  -r - the term following -r in quotes will be interpreted as a
       regex following conventions in man re_format(7).  Any other
       command line term is ignored (except speficied by flag).
  -v - specify a volume to search pkgs on.  Defaults to "/"
  -h - shows this text.

If -r is not specified, we do a case insensitive substring search
  using the first whole word argument supplied.  Essentially
  pkg_search_installed -r "(?i).*searchterm.*"
EOF
  }
  shift $(($OPTIND - 1))
  nextarg="${1:-}"
  IFS='' read -r -d '' warning <<'EOF'
  Please use pkg_search_installed to make sure you have only the packages
  you want to remove.  This function does not ask for confirmation, PROCEED
  AT YOUR OWN RISK.
EOF
  echo "$warning"
  if ! confirm_yes_default_no "OK to proceed? (y/N)?"; then
    return 5
  fi
  if [ -z "$regex" ]; then
    printf -v regex '(?i).*%s.*' "${1:-}"
  fi
  files=()
  dirs=()
  for pkg in $(pkgutil --volume / --pkgs="$regex"); do
    while IFS=$'\n' read -r line ; do
      files+=( "$line" )
    done < <(pkgutil --files "$pkg" --only-files)
    while IFS=$'\n' read -r line ; do
      dirs+=( "$line" )
    done < <(pkgutil --files "$pkg" --only-dirs)
  done
  for file in "${files[@]}"; do
    echo "rm -f $file"
  done
  for dir in "${dirs[@]}"; do
    echo "rmdir $dir"
  done
  for pkg in $(pkgutil --volume / --pkgs="$regex"); do
    sudo pkgutil --forget "$pkg"
  done
  return $?
}


# https://stackoverflow.com/questions/54995983/how-to-detect-availability-of-gui-in-bash-shell
function check_macos_gui() (
  command -v swift >/dev/null && swift <(cat <<"EOF"
import Security
var attrs = SessionAttributeBits(rawValue:0)
let result = SessionGetInfo(callerSecuritySession, nil, &attrs)
exit((result == 0 && attrs.contains(.sessionHasGraphicAccess)) ? 0 : 1)
EOF
)
)