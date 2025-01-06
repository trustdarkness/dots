#!/usr/bin/env bash
alias vsc="vim $HOME/.ssh/config"
alias pau="ps auwx"
alias paug="ps auwx|grep "
alias paugi="ps awux|grep -i "
alias rst="sudo shutdown -r now"
alias gh="mkdir -p $HOME/src/github && cd $HOME/src/github"
alias gl="mkdir -p $HOME/src/gitlab && cd $HOME/src/gitlab"
alias gc="git clone"
export GH="$HOME/src/github"

shopt -s expand_aliases
set -E
trap 'echo "$LINENO $BASH_COMMAND ${BASH_SOURCE[*]} ${BASH_LINENO[*]} ${FUNCNAME[*]}"' ERR

if ! declare -F "exists" > /dev/null 2>&1; then
  source "$D/existence.sh"
fi

warn() { 
  echo "$@" 
} # until we merge in logging
alias error=warn

# A slightly more convenient and less tedious way to print
# to stderr, canonical in existence # TODO, check namerefs on resource
if ! is_declared "se"; then
  # Args: 
  #  Anything it recieves gets echoed back.  If theres
  #  no newline in the input, it is added. if there are substitutions
  #  for printf in $1, then $1 is treated as format string and 
  #  $:2 are treated as substitutions
  # No explicit return code 
  function se() {
    if [[ "$*" == *'%'* ]]; then
      >&2 printf "${1:-}" $:2
    else
      >&2 printf "$@"
    fi
    if ! [[ "$*" == *'\n'* ]]; then 
      >&2 printf '\n'
    fi
  }
fi

# for my interactive shells, the full environment setup is constructed
# from bashrc, but for scripts that rely on it, this function should be
# called to make sure all is as expected.
# TODO: create teardown that remove all namerefs added by setup
function util_env_load() {
  # this represents all the possible sources at the moment, but only
  # including as options as needed, otherwise it would be taking an 
  # already silly thing and making it ridiculous.
  local exu=true # -e
  local up=false # -u
  local fsau=false # -f
  local osu=true # -o
  local jl=false # -j
  local xl=false # -x
  local ku=false # -k
  local lb=false # -l
  local iu=false # -i
  local md=false # -d
  local bs=false # -b
  while [ $# -gt 0 ]; do
    case "${1:-}" in
      "-e"|"--existence")
        exu=true
        shift 
        ;;
      "-f"|"--filesystemarray")
        fsau=true
        shift
        ;;
      "-j"|"--json-like")
        jl=true
        shift
        ;;
      "-x"|"--xml-like")
        xl=true
        shift
        ;;
      "-u"|"--user-prompts")
        up=true
        shift
        ;;
      "-i"|"--installutil")
        iu=true
        shift
        ;;
      "-d"|"--macdebug")
        md=true
        shift
        ;;
      "-b"|"--bootstraps")
        bs=true
        shift
        ;;
      "-o"|"--osutil")
        osu=true
        shift
        # TODO: finish implementing
        ;;
      "-j"|"--json-like")
        osu=true
        shift
        # TODO: finish implementing
        ;;
      *)
        echo "Boo.  ${1:-} does not exist"
        shift 
        ;;
    esac
  done
  if ! declare -F "exists" > /dev/null 2>&1 && $exu; then
    source "$D/existence.sh"
  fi
  if undefined "confirm_yes" && $up; then
    source "$D/user_prompts.sh"
  fi
  if undefined "xmllike" && $xl; then
    source "$D/xml_like.sh"
  fi
  if undefined "json_like_tl" && $jl; then
    source "$D/json_like.sh"
  fi
  if undefined "dirarray" && $fsau; then
    source "$D/filesystemarrayutil.sh"
  fi
  if undefined "binmachheader" && $md; then
    source "$D/macdebug.sh"
  fi
  if untru $osutil_in_env && $osu; then
    osutil_load
  fi
  if undefined "sau" && $iu; then
    install_util_load
  fi
  if undefined "term_bootstrap" && $bs; then 
    source "$D/bootstraps.sh"
  fi
}

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

dgrep() {
  grepargs=()
  while [[ "${1:-}" == "-"* ]]; do
    grepargs+=( "${1:-}" )
    shift
  done
  sterm="${1:-}"
  if [ -z "$D" ]; then 
    if confirm_yes "D not in env, do you want to search PATH?"; then 
      #TODO
      :
    fi
  fi
  total_found=0
  for item in "$D"/*; do 
    # if there are ever more exceptions, make this more visible
    { [ -f "$item" ] && [[ "$item" != *LICENSE ]] && file=$item; } || continue
    found=$(grep -n ${grepargs[@]} "$sterm" "$file"); ret=$?||true
    if [ $ret -eq 0 ]; then
      echo "$file"
      while read -r line ; do
        echo "  ${line/$sterm/${GREEN}${sterm}${RST}}"
      done < <(echo "$found")
      echo
      ((total_found+=$(echo "$found"|wc -l|xargs)))
    fi
  done
  if [ $total_found -gt 0 ]; then 
    return 0
  fi
  return 1
}

function symlink_verbose() {
  se "linking target $target from link name $linkname"
  ln -sf "$target" "$linkname"
}

# TODO: make this less brittle
function move_verbose() {
  mvv_force=false
  if [[ "${1:-}" == "-f" ]]; then
    mvv_force=true
    shift
  fi
  printf "moving %s to %s" "${1:-}" "${2:-}"
  if tru $mvv_force; then
    echo " with -f"
    mv -f "${1:-}" "${2:-}"
  else
    echo
    mv "${1:-}" "${2:-}"
  fi
}

function lns() {
  local target="${1:-}"
  local linkname="${2:-}"
  if [ -h "$linkname" ]; then
    ln -si "$target" "$linkname"
  elif [ -f "$linkname" ]; then
    move_verbose "$linkname" "$linkname.bak"
    symlink_verbose "$target" "$linkname"
  else
    symlink_verbose "$target" "$linkname"
  fi
}

function lnsdh() {
  lns "$D/${1:-}" "$HOME/${1:-}"
}

function gpgvc() {
  gpg --verify < <(xclip -o)
}

function gpgic() {
  gpg --import < <(xclip -o)
}

# preferred format strings for date for storing on the filesystem
FSDATEFMT="%Y%m%d" # our preferred date fmt for files/folders
printf -v FSTSFMT '%s_%%H%%M%%S' "$FSDATEFMT" # our preferred ts fmt for files/folders
LAST_DATEFMT="%a %b %e %k:%M" # used by the "last" command
HISTTIMEFORMAT="$FSTS"

function fsdate() {
  date +"${FSDATEFMT}"
}

function fsts_to_fsdate() {
  date -d -f "$FSTSFMT" "${1:-}" "$FSDATEFMT"
}

function fsts() {
  date +"${FSTSFMT}"
}

function is_fsts() {
  fsts_to_unixtime $@ > /dev/null 2>&1
  return $?
}

function is_fsdate() {
  date "+$FSDATEFMT" -d "${1:-}" > /dev/null 2>&1
  return $?
}

function fsts_to_unixtime() {
  if is_mac; then
    date -jf "$FSTSFMT" "${1:-}" +%s
  else
    date -d -f "$FSTSFMT" "${1:-}" +"%s"
  fi
  return $?
}

function colnum() {
  help() {
    echo "echos the column number of substring in string if found"
    echo "returns 0 if successful, 255 if substring not found, 1 otherwise"
    return 0
  }
  substring="${1:-}"
  string="${2:-}"
  if empty "$substring" || empty "$string"; then
    help 1
  fi
  rest=${string#*"$substring"}
  se "$rest"
  c=$(( ${#string} - ${#rest} - ${#substring} ))
  if gt $c 0; then
    echo $C
    return 0
  else
    return 255
  fi
  return 1
}

# Normalize os detection for consistency, hopefully reducing the chance
# of simple typo, etc mistakes and increasing readability
function is_mac() {
  if [[ "$(uname)" == "Darwin" ]]; then
    return 0
  fi
  return 1
}

function is_linux() {
  if [[ "$(uname)" == "Linux" ]]; then
    return 0
  fi
  return 1
}

function what_os() {
  if is_mac; then echo "MacOS"; return 0; fi
  if is_linux; then echo 'GNU/Linux'; return 0; fi
}

function pidinfo() {
  local line="$(ps awux | grep ${1:-})"
  local dirtyname="$(echo \"$line\" | awk -F':' '{print$NF}')"
  echo $dirtyname
  local name="${dirtyname:6}"
  local cpu="$(echo \"$line\"|awk '{print$3}')"
  local mem="$(echo \"$line\"|awk '{print$4}')"
  local started="$(echo \"$line\"|awk '{print$9}')"
  IFS='' read -r -d '' pidinfo <<"EOF"
 Process: %s
   PID: %s
   Current CPU: %s %%
   Current RAM: %s %%
   Started at: %s
EOF
  printf "$pidinfo" "$name" "$cpu" "$mem" "$started"
}

function add_permanent_bash_alias_to_bashrc() {
  name="${1:-}"
  to="${2:-}"
  rationale="${3:-}"
  ts=fsts
  if [ -n "$to" ] && ! is_quoted "$to"; then
    to=$(shellquote "$to")
  fi
  mkdir -p "$HOME/.local/bak"
  fs_rationale=$(echo "$rationale"|sed  's/ /_/g')
  se "existing .bashrc backed up to $HOME/.local/bak/.bashrc.bak.$ts.$fs_rationale"
  # https://stackoverflow.com/questions/5573683/adding-alias-to-end-of-alias-list-in-bashrc-file-using-sed
  tac .bashrc |
  awk "FNR==NR&&/alias/{s=FNR;next}FNR==s{ \$0=\$0\"\nalias $name=\x22$to\x22\n\"}NR>FNR" .bashrc .bashrc > .bashrc.new
  mv "$D/.bashrc" "$HOME/.local/bak/.bashrc.bak.$ts.add_synergy_alias" && mv .bashrc.new .bashrc
  return $?
}

function is_bash_script() {
  if [ -z "$script" ] || ! [ -f "$script" ]; then
    return 1
  fi
  head -n1 "$script" | grep "bash$" > /dev/null 2>&1
  return $?
}

VALID_POSIXPATH_EL_CHARS='\w\-. '
printf -v VALID_POSIXPATHS_REGEX '[\/*%s]+' "$VALID_POSIXPATH_EL_CHARS";
BASH_FUNCTION_PCREREGEX='(function [A-z0-9_]+ *\(\) +{|[A-z0-9_]+ *\(\) +{|[A-z0-9_]+ +{)'
_BWVR='^bash[_-]{0,1}(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|'
_BWVR+='[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*'
_BWVR+='[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$'
BASH_WITH_VERSION_REGEX="$_BWVR"

bash_shebang_validator() {
  _env_ok() {
    to_test="${1:-}"
    { pcregrep "\#\!$VALID_POSIXPATHS_REGEX" < <(echo "$to_test"); ret=$?; } ||
      { "$BASH_COMMAND failed with ret $ret"; return 9; }
    if [ $ret -eq 0 ]; then
      # this is now an array but we bastardized the functionality to pop
      # off the first word and so we'll just treat it like variable 
      shebangcmd="${to_test%% *}"
      bangcmd="${shebangcmd:2}"
      if ! [ -x "$bangcmd" ] || ! [ -s "$bangcmd" ]; then 
        return 2
      fi
      if [[ "$bangcmd" != *'env' ]]; then 
        return 3
      fi
    fi
    if [ -n "$bangcmd" ]; then 
      testout=$($bangcmd "VARNAME=value" "bash" "-c" 'echo $VARNAME'); ret=$?
      if [[ "$testout" == "value" ]]; then return 0; fi
      # if the test succeeds, we should never reach the next line
      error "expected first part of shebang with spaces to be env, but got $bangcmd"
      return 6
    fi
    return 4 
  }
  bash_script="${1:-}"
  she_bang=$(head -n 1 "${bash_script}") || \
    { se "failed to head $bash_script"; return 6; }
  if [[ "$she_bang" == *' '* ]]; then 
    # valid shebangs for bash scripts with a space should call env 
    # to later call bash; split on space
    IFS=' ' read -r -a shebang_components <<< "${she_bang}"
    sheenv="${shebang_components[0]}"
    bashend="${shebang_components[-1]}"
    _env_ok "$sheenv" || {
      w="Shebang contains a space, which means the first term should point to env ";
      w+="but instead points to $sheenv.";
      warn "$w";
      return 7;
    }
    echo "bashend: $bashend"
  else
    bashend="$she_bang"
  fi
  if [[ "$bashend" == *'bash' ]]; then 
    return 0
  else
    [[ "$bashend" =~ $BASH_WITH_VERSION_REGEX ]] && return 0 
    error "bash does not appear to be in shebang $she_bang of $bash_script"
    return 5 
  fi
} 

# given a filename, return an alphanumeric (plus underscores) version
function slugify() {
  name="${1:-}"
  ext=
  unset slugified # if this is needed, should be copied into the local namespace
  declare -gA slugified
  if string_contains "/" "$name"; then 
    dn=$(dirname "$name")
    name=$(basename "$name")
  fi
  old_name="$name"
  if [[ "${name}" =~ ^[\w,\s-]+[\.[A-Za-z]]+ ]]; then 
    ext="${name##*.}"
    name="${name%.*}"
  fi
  slugified_name=$(echo "$name"| sed 's/^\./_/g'| sed 's/ /_/g' |sed 's/[^[:alnum:]\t]//g')
  if [ -n "$ext" ]; then slugified_name="$slugified_name.$ext"; fi
  slugified["$slugified_name"]="$old_name"
  echo "$slugified_name"
  return 0
}

function_finder() {
  unset ffs
  ffs=()
  local flinenos=false
  local nested=false
  local have_dirs=false
  local have_files=false
  local wide=false
  local files
  unset files
  local dirs
  unset dirs
  optspec="ld:f:F:wh"
  unset OPTIND
  unset optchar
  while getopts "${optspec}" optchar; do
	local OPTIND
	case "${optchar}" in
	  l)
      flinenos=true
      ;;
    d)
      dirs+=( "${OPTARG}" )
      have_dirs=true
      ;;
    f)
      filepath="${OPTARG}"
      ;;
    F)
      function_name="${OPTARG}"
      ;;
    w)
      wide=true
      ;;
	  h)
      usage
      return 0
      ;;
	  *)
      usage
      return 1
      ;;
	esac
  done
  shift $(($OPTIND - 1))
  local _argc_post=$1

  # supported filetypes for the moment will be bash and c, but may expoand
  # over time
  ff_supported_types=( "sh" "c" )

  _dir_or_file() {
    local to_test="${1:-}"
    if [ -d "$to_test" ]; then 
      have_dirs=true
      dirs+=( "$to_test" )
      return 0
    elif [ -s "$to_test" ]; then
      have_files=true
      files+=( "$to_test" )
      return 0 
    else
      return 1
    fi
  }

  _functions_in_file() {
    filename="${1:-}"
    filebn=$(basename "$filename")
    slugged=$(slugify "$filebn")
    unset "linesfunctions_in_$slugged"
    declare -ga "linesfunctions_in_$slugged"
    declare -n arr="linesfunctions_in_$slugged"
    # local arr="${!nref}"
    ffs+=("linesfunctions_in_$slugged")


    while IFS= read -r line; do
      arr+=( "$line" ) 
    done < <(pcre2grep --null -n "$BASH_FUNCTION_PCREREGEX" "$filename")
  }
  _process_line() {
    line="${1:-}"
    if [[ "$line" == "#"* ]]; then return 1; fi
    processed=$(echo "$line"|
      sed 's/function //g'| # remove any function keywords
      sed 's/\(\h*\)\h*{//g'|
      sed 's/\(.*\) || //g'|
      sed 's/()//g') # remove parens and brackets
                              # TODO: will need to be updated
                              # if we still want to lazily 
                              # support c
    if [ -n "$processed" ]; then echo "$processed"; return 0; fi
    return 1
  }

  util_env_load -e -f
  # we assume either filname or function for positional args
  for arg in "$@"; do 
    script="${1:-}"
    functions=()
    # this is silly
    _dir_or_file "$script" || functions+=( "$script" )
  done
  if $have_dirs; then 
    for dir in "${dirs[@]}"; do 
      for filename in "$dir"/*; do 
        if in_array "${filename#*.}" "ff_supported_types"; then 
          have_files=true
          abspath=$(realpath "$filename")
          files+=( "$abspath" )
        fi
      done
    done
  fi
  if $have_files; then 
    for filepath in "${files[@]}"; do 
      bn=$(basename "$filepath")
      dn=$(dirname "$filepath")
      { swd=$(pwd); cd "${dn}"; } || { error "couldn't cd to $dn"; return 5; }
      _functions_in_file "$bn" && cd "$swd" || \
        { warn "no functions found in $filepath";  }
    done
  fi

  i=0
  if $wide; then 
    pager=column
  else
    pager=cat # essentially a noop
  fi
  for name in "${ffs[@]}"; do
    oname=${slugified[$(echo "$name" |cut -d"_" -f3-)]}
    echo "$oname"
    local -n arr="$name"
    # se "${arr[*]}"
    for linefunction in "${arr[@]}"; do 
      lineno=$(echo "$linefunction" | cut -d":" -f1) 
      fline=$(echo "$linefunction" | cut -d":" -f2)
      { fname=$(_process_line "$fline") && 
        { if $flinenos; then
            printf "%4d " "$lineno"
          fi
          printf "%s\n" "$fname"
          ((i++)) } 
      } || continue
    done | $pager
    echo
  done

}

print_function() {
  filepath=
  flinenos=false
  optspec="lf:h"
  unset OPTIND
  unset OPTARG
  unset optchar
  while getopts "${optspec}" optchar; do
    case "${optchar}" in
      l)
        flinenos=true
        ;;
      f)
        filepath="$OPTARG"
        [ -f "$filepath" ] || error "no file at $filepath"; return 2;
        ;;
      h)
        usage
        return 0
        ;;
      *)
        usage
        return 1
        ;;
    esac
  done
  shift $(($OPTIND - 1))
  function_name="${1:-}"
  if [ $# -gt 1 ]; then
    if [ -f "${2:-}" ]; then
      filepath="${2:-}"
    fi
  elif [ $# -gt 2 ]; then
    usage
  fi
  if [ -z "$filepath" ]; then
    # for convenience
    warn "no filename provided, trying to get $function_name from env"
    declare -pf "$function_name"
    return $?
  fi
  while IFS= read -r line; do
    nums_names+=( "$line" )
  done < <(function_finder -l "$filepath"|grep "$function_name")
  if [ "${#nums_names[@]}" -gt 0 ]; then 
    for num_name in "${nums_names[@]}"; do 
      num=$(echo "$num_name" | awk '{print$1}')
      name=$(echo "$num_name" | awk '{print$2}')
      if ! is_int "$num"; then
        # logvars=(num_name num name filepath function_name); debug
        error "couldn't parse line number from function_finder"
        return 4
      fi

      alllines=$(wc -l "$filepath"| awk '{print$1}')
      tailtop=$((alllines-num))
      endline=$((num+$(tail -n "$tailtop" "$filepath"|grep -n -m 1 '^}$'| cut -d ":" -f 1)))
      if ! is_int "$endline"; then
        #logvars=(num_name num name endline filepath function_name); debug
        error "couldn't parse line number from function_finder"
        return 4
      fi
      #logvars=(flinenos num_name num name alllines tailtop endline filepath function_name); debug
      if $flinenos; then
        # printf -v awkvars 'FNR==%d,FNR==%d' "$num" "$endline"
        # printf -v awkcmd '%s {print FNR ":" $0}' "$awkvars"
        # awk "$awkcmd" "$filepath"; return $?
        sed -n "$num,${endline}{=;p};${endline}q" "$filepath"| sed '{N; s/\n/ /}';
      else
        sed -n "$num,${endline}p;${endline}q" "$filepath"
      fi
      echo
    done
  else
    bn=$(basename "$filepath")
    error "couldn't find definition for $function_name at the top level of $bn"
    return 3
  fi
  #logvars=(flinenos num_name num name alllines tailtop endline filepath function_name); debug

}

function namerefs_bashscript_add() {
  script="${1:-}"
  if ! is_bash_script; then
    se "please provide a path to a bash script"
  fi
  if ! declare -p "VALID_DECLARE_FLAGS" > /dev/null 2>&1; then
    source "$D/existence.sh"
  fi
  if undefined "in_array"; then
    source "$D/filesystemarrayutil.sh"
  fi

  # our main container for names
  declare -a _names

  # case: global function names
  _names=$(function_finder)

  # get variables declared as local for exclusion (this may ressult in false positives)
  declare -ga localvars
  declare -a localvarlines
  localvarlines=( $(grep '^[[:space:]]*local [[:alnum:]]*_*[[:alnum:]]*' "$script") )
  for line in "${localvarlines[@]}"; do
    wequal=$(echo "$line"|grep "=")
    if [ $? -eq 0 ]; then
      # we're expecting something like "local foo=bar" and we want foo
      localvars+=( $(echo "$wequal" | awk '{print$1}' |awk -F'=' '{print$1}') )
    else
      localvars+=( $(echo "$line" | awk '{print$2}') )
    fi
  done

  # case variables declared by assignment
  declare -a vars
  vars=$(grep '^[[:space:]]*[[:alnum:]]*_*[[:alnum:]]*=' "$script" |awk -F'=' '{print$1}'|xargs)

  # case: names declared in the global scope
  vars+=( $(grep ^declare "$script" |awk '{print"\x22"$3"\x22"}') )

  # case: variables assigned by printf
  vars+=( $(grep "printf -v" "$script" |awk '{print"\x22"$3"\x22"}') )

  # only populate from the above 2 cases when not declared with the local keyword
  for var in "${vars[@]}"; do
    if ! in_array "$var" "localvars"; then
      var=$(singlequote "$var")
      _names+=( "$var" )
    fi
  done

  # names declared not in the global namespace but with -g
  printf -v declaregregex '^[[:space:]]*declare -[%s]*g[%s]*' "$VALID_DECLARE_FLAGS" "$VALID_DECLARE_FLAGS"
  _names+=( $(grep "$declaregregex" "$script" |awk '{print"\x22"$3"\x22"}') )

  noextbasename=$(basename "$script"|sed 's/.sh//g')
  expected_name="NAMEREFS_${noextbasename^^}"
  existing_namerefs="$(grep '^NAMEREFS_[[A-z]]=(.*)$')"
  if [ $? -eq 0 ]; then
    name=$(echo "$existing_namerefs"|awk -F'=' '{print$1}')
    if [[ "$name" == "$expected_name" ]]; then
      eval "$existing_namerefs"
    else
      se "found $name in $script which didn't match expected $expected_name"
      return 1
    fi
  fi
  if undefined "$expected_name"; then
    declare -a "$expected_name"
  fi
  local -n script_namerefs=("${!expected_name[@]}")
  script_namerefs+=( $_names )
  # make sure we're quoted for printing
  declare -a out_namerefs
  for nameref in "${script_namerefs[@]}"; do
    if ! is_quoted "$nameref"; then
      out_namerefs+=( $(singlequote "$nameref") )
    else
      out_namerefs+=( "$nameref" )
    fi
  done
  # remove the original reference
  sed -i 's/^NAMEREFS_[[A-z]]=(.*)$//g' "$script"
  # add it in a nice-to-look-at format:
  printf "\n\n${expected_name}=(" >> "$script"
  for quoted_nameref in "${out_namerefs[@]}"; do
    printf "$quoted_nameref" >> "$script"
  done
  printf ")\n" >> "$script"
}



# find wrappers for common operation modes, even when they vary by OS.
# This is the kind of thing that should normally go in osutil, but
# there is something useful about seeing the differences side-by-side
# and not having to be concerned that any troubleshooting might be OS
# specific.  We capture the args just like as if we were running the
# real find and populate our changes into the args dict in an order that
# shouldn't disrupt the original intention.  To ease troubleshooting,
# we export three globals on run:
# [L,M,C]FIND_IN - $@ array as it was passed to the function
# [L,M,C]FIND_RUN - full command as it was run, including any local
#                   alteration to handles; but nothing external, pipelines, etc
# [L,M,C]FIND_STACK - the call stack ${FUNCNAME[@]} at execution
#
# (TODO: would it be useful to keep in-memory
# histories in global arrays?)
COMPOSABLE_FINDS=( "cfind" "lfind" )

function compose_find() {
set -x
  caller="${FUNCNAME[1]}"
  to_compose=( "$@" )
  local -n run_args="${caller^^}_RUN"
  caller_args=("${run_args[@]:1}")
  composed=false
  declare -A called
  # jacob told me that I am a candidate, do you know what that means?
  for candidate in "${COMPOSABLE_FINDS[@]}"; do
    if [[ "$candidate" != "$caller" ]]; then
      if [[ "${to_compose[*]}" == *"$candidate"* ]]; then
        # candidate is in the call stack
        composed=true
        called["$candidate"]="$caller"
        caller="$candidate"
        run_args=( $(eval "${candidate}_args" "${run_args[@]}") )
      fi
    fi
  done
  # let us do a little validation; our wrong side of the tracks unit tests
  if $composed; then
    if [[ "${caller_args[*]}" == "${run_args[*]}" ]]; then
      se "find should be composed but only found args from ${FUNCNAME[1]}"
      se "should have found:"
      for caller in "${!called[@]}"; do
        se "$caller : ${called[$caller]}"
      done
      return 2
    fi
    declare -a missing_caller_args
    for caller in "${!called[@]}"; do
      if [[ "$caller" == "${FUNCNAME[1]}" ]]; then
        local_caller_args=( "${caller_args[@]}" )
      else
        local_caller_args=( $"${caller^^}_RUN" )
      fi
      for arg in "${local_caller_args[@]}"; do
        if [[ "${run_args[*]}" != *"$arg"* ]]; then
          missing_caller_args+=( "$arg" )
        fi
      done
      if gt ${#missing_caller_args[@]} 0; then
        se "all caller_args should have been in \$run_args, but $caller were missing:"
        se "${missing_caller_args[@}}"
        return 3
      fi
    done
  fi
  find "${run_args[@]:1}"
  return $?
}

function find_composed_of() {
set -x
  caller="${FUNCNAME[1]}"
  in_args="${caller^^}_IN"
  declare -a new_args
  for arg in "${in_args[@]}"; do
    if [[ "$arg" != "find" ]] && [[ "$arg" != "$caller" ]]; then
      if [[ "${COMPOSABLE_FINDS[@]}" != *"$arg"* ]]; then
        new_args+=( "$arg" )
      else
        composed=true
        to_compose+=( "$arg" )
      fi
    fi
  done
  in_args=( "${new_args[@]}" )
  if gt ${#to_compose[@]} 0; then
    echo "${to_compose[@]}"
    return 0
  fi
  return 1
}


# If for any sourced file, you'd like to be able to undo the
# changes to  your environment after it's sourced, track the
# namerefs (variable, function, etc names) in an array named
# sourcename_namerefs where the sourced filename is
# sourcename.sh, when you want to clean the namespace of that
# file, call cleaup_namespace sourcename, and it will be done
# see macboot.sh for example
function cleanup_namespace() {
  local namespace="${1}"
  local -n to_clean="${namespace}_namerefs"
  to_clean=${!to_clean}
  for nameref in "${to_clean[@]}"; do
    unset ${nameref}
  done
}

# for things you only want there when the above DEBUG flag is set
function dse() {
  if $DEBUG; then
    if [ $# -eq 2 ]; then
      >&2 printf "${1:-}\n" "${@:2:-}"
    else
      >&2 printf "${1:-}\n"
    fi
  fi
}

# Arg1 is needle, Arg2 is haystack
# returns 0 if haystack contains needle, retval from grep otherwise
function string_contains() {
  echo "${@:2}"| grep -Eqi "${1:-}"
  return $?
}
alias stringContains="string_contains"

function shellquote() {
  if [[ "$1" =~ ".*" ]]; then
    echo $1
  fi
  printf '"%s"\n' "$@"
}

# returns zero if the value referenced by $1 has literal quotes surrounding it
# works for single or double quotes, returns 1 otherwise
function is_quoted() {
  if [[ "${1:-}" =~ \'.*\' ]]; then
    return 0
  elif [[ "${1:-}" =~ \".*\" ]]; then
    return 0
  fi
  return 1
}

# for a multiline string, returns a string with doublequotes surrounding
# each line of the given string as a part of the string
function shellquotes() {
  for line in ${1:-}; do
    shellquote "${line}"
  done
}

# returns given args as strings with single quotes surrounding
function singlequote() {
  printf "'%s'\n" "$@"
}

# for a multiline string, returns a string with singlequotes surrounding
# each line of the given string as a part of the new string
function singlequotes() {
  for line in ${1:-}; do
    singlequote "${line}"
  done
}

# shell escapes terms given as arguments (%q)
function shellescape() {
  printf "%q\n" "$@"
}

# for a multiline string, returns a string with each line of the new string
# being a shell quoted version of the original (%q)
function shellescapes() {
  for line in ${1:-}; do
    shellescape "${line}"
  done
}

# Returns the architecture of the running system
function system_arch() {
  uname -m
}

in-path() {
  to_find="${1:-}"
  found=()
  while IFS= read -r -d $'\0' file; do
    found+=( "$file" )
  done < <(find $(echo "$PATH" | tr ":" " ") -type f -name "$to_find" -print0 2>/dev/null)
  if [ ${#found[@]} -eq 0 ]; then
    return 1
  fi
  for item in "${found[@]}"; do echo "$item"; done
  return 0
}

# Appends Arg1 to the shell's PATH and exports
function path_append() {
  to_add="${1:-}"
  if [ -d "${to_add}" ]; then
    if ! [[ "${PATH}" == *"${to_add}"* ]]; then
      export PATH="${PATH}:${to_add}"
    fi
  fi
}

# Prepends Arg1 to the shell's PATH and exports
function path_prepend() {
  to_add="${1:-}"
  if [ -d "${to_add}" ]; then
    if ! [[ "${PATH}" == *"${to_add}"* ]]; then
      export PATH="${to_add}:${PATH}"
    fi
  fi
}


function printcolrange() {
  input="${1:-}"
  start="${2:-}"
  fin="${3:-}"
  delim="${4:-}"
  top="$t"
  if lt "$fin" 0; then
    prog='{for(i=f;i<=t'+$fin+';i++) printf("%s%s",$i,(i==t)?"\n":OFS)}'
  else
    prog='{for(i=f;i<=t;i++) printf("%s%s",$i,(i==t)?"\n":OFS)}'
  fi
  echo "$input"|awk "$start,NF$fin { print NR, $0 }"
}

# Given a date (Arg1) and a fmt string (Arg2, strftime),
# returns 0 if that date was more than 7 days ago, 1 otherwise
function is_older_than_1_wk() {
  d="${1:-}"
  fmt="${2:-}"
  if ! [ -n "${fmt}" ]; then
    if [ "${#d}" -eq 8 ]; then
      fmt=$FSDATEFMT
    elif [ "${#d}" -eq 15 ]; then
      fmt=$FSTSFMT
    else
      se "Please provide a date format specifier"
      return 1
    fi
  fi
  ts=$(date -f +"$fmt" -d "${d}" +"%s")
  now=$(date +"%s")
  time_difference=$((now - ts))
  days=$((time_difference / 86400)) #86400 seconds per day
  if [ $days -gt 7 ]; then
    return 0
  fi
  return 1
}

function update_ssh_ip() {
  host="${1:-}"
  octet="${2:-}"
  out=$(grep -A2 "$host" $HOME/.ssh/config)
  local IFS=$'\n'
  for line in out; do
    line=$(echo $line |xargs)
    ip=$(grep "hostname" <<< "$line" | awk '{print$2}')
  done
  printf -v sedexpr "s/%s/%s/g" "$ip" "10.1.1.$octet"
  sed -i "$sedexpr" "$HOME/.ssh/config"
}

# this only kinda sorta works IIRC
# Intended to grab ip or hostname values from the nearest source possible
# starting with /etc/hosts, .ssh/config, then out to dig, other place
# echo hostname or ip from host alias to the console no explicit return
function hn () {
  if [ $# -eq 0 ]; then
    >&2 printf "give me a list of hosts to get ips for"
    return 1;
  fi

  IPR='^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.){3}(25[0-5]|(2[0-4]|1\d|[1-9]|)\d)$'

  # get hosts from ssh config
  for h in $(echo $@| tr " " "\n"); do
    SSHOST="$(grep -A2 $h $HOME/.ssh/config|grep hostname)"
    if [ $? -ne 0 ]; then
      IP="$(echo $SSHOST|grep '$IPR')"
      if [ $? -ne 0 ]; then
        echo "$h: $IP"
      fi
    fi
    if [ -n "$IP" ]; then
      dig $h
    fi
    IP=""
  done
}

# does a best effort search of a bash source file $2
# and attemtps to determine if the given function $1
# is called in that file, returns 0 if so and echos
# the surrounding code to the console, 1 if not found
# or indeterminite
function is_called() {
  func="${1:-}"
  found=$(grep -n -B3 -A3 "$func" "${2:-}" |grep -v '^#' |sed "s/$func/${RSL}${func}${RST}/g")
  echo "$found"
}

function is_absolute() {
  local dir="${1:-}"
  if [ -d "${dir}" ]; then
    if startswith "/" "${dir}"; then
      return 0
    fi
  fi
  return 1
}

function startswith() {
  local query="${2:-}"
  local starts_with="${1:-}"
  if [[ "$query" =~ ^$starts_with.* ]]; then
    return 0
  fi
  return 1
}

function symlink_child_dirs () {
   undo_dir="$CACHE/com.trustdarkness.utilsh"
  help() {
    >&2 printf "Specify a target parent directory whose children\n"
    >&2 printf "should be symlinked into the desitination directory:\n"
    >&2 printf "\$ symlink_child_dirs [target] [destination]"
  }
  undo_last_change() {
    undo_file=$(most_recent "$undo_dir")
    while string_contains "undone" "$undo_file"; do
      undo_file=$(most_recent "$undo_dir")
    done
    declare -a to_remove
    for line in $(cat "$undo_file"); do
      if [ -h "$line" ]; then
        to_remove+=( "$line" )
        echo "$line"
      fi
    done
    echo
    if confirm_yes "removing the above symbolic links, OK?"; then
      for link in "${to_remove[@]}"; do
        rm -f "$link"
      done
      mv "$undo_file" "${undo_file}.undone"
      return 0
    else
      echo "exiting with no changes"
      return 0
    fi
  }
  optspec="u?h"
  while getopts "${optspec}" optchar; do
    case "${optchar}" in
      u)
        if undo_last_change; then
          se "undo successfully completed"
          return 0
        else
          se "undo failed with code $?"
          return 1
        fi
        shift
        ;;
      h)
        help
        shift
        ;;
    esac
  done
  # Argument should be a directory who's immediate children
  # are themes such that you want to have each directory
  # at the top level (under the parent) symlinked in a
  # target directory.  Intended for use under ~/.themes
  # but presumably, there are other ways this is useful.
  target="${@:$OPTIND:1}"
  whereto="${@:$OPTIND+1}"

  failures=0
  successes=0
  declare -a failed_targets
  declare -a undos
  if [ -d "$target" ]; then
    if ! is_absolute "$target"; then
      echo "the target directory should be an absolute path"
      return 1
    fi
    if [ -d "$whereto" ]; then
      if find $target ! name '.git' -maxdepth 1 -type d -exec ln -s '{}' $whereto/ \;; then
        undos+=( "$whereto/$target" )
        ((successes++))
      else
        ((failures++))
        failed_targets+=( "$whereto/$target" )
      fi
    fi
  else
    echo "arg1 should be a directory containing children to symlink"
    return 1
  fi
  if gt $successes 0; then
    ts=$(fsts)
    undo_dir="$CACHE/com.trustdarkness.utilsh"
    mkdir -p "$undo_dir"
    undo_file="$undo_dir/${FUNCNAME[0]}.$ts.undo"
    for line in "${undos[@]}"; do
      echo "$line" >> "$undo_file"
    done
    echo "Changes recorded at $undo_file, run ${FUNCNAME[0]} -u to undo"
    echo
  fi
  if gt $failures 0; then
    se "failed to create the following:"
    for failure in "${failed_targets[@]}"; do echo "$failure"; done
  fi
}

# thats too long to type though.
alias scd="symlink_child_dirs"

function most_recent() {
  local dir="${1:-.}"
  local sterm="${2:-}"
  local files
  if [ -n "$sterm" ]; then
    files="$(find ${dir} -name "*$sterm*" -maxdepth 1 -mindepth 1 -print0 2> /dev/null|tr '\0' '|'|tr ' ' '+')"
  else
    files="$(find ${dir} -maxdepth 1 -mindepth 1 -print0 2> /dev/null|tr '\0' '|'|tr ' ' '+')"
  fi
  #echo "$files"
  local most_recent_crash=$(most_recent "${files}")
  # find gives you back \0 entries by default, which would be fine, and
  # non-printable characters are probably better for a lot of reasons, but
  # not for debugging.  We default to these, but you may set whatever you
  # like with args 2 and 3
  local default_filename_separator="|"
  local default_space_replacer="+"
  local char_replaced_separated_files=("${files[@]}")
  local filename_separator="|"
  local space_replacer="+"
  readarray -d"$filename_separator" files < <(echo "${char_replaced_separated_files}")

  # https://stackoverflow.com/questions/5885934/bash-function-to-find-newest-file-matching-pattern
  for messyfile in "${files[@]}"; do
    file="$(echo ${messyfile}|tr "${space_replacer}" ' '|sed "s/${filename_separator}//g")"
    if [ -n "${file}" ]; then
      stat -f "%m%t%N" "${file}"
    fi
  done | sort -rn | head -1 | cut -f2-
}

# Convenience function for github clone, moves into ~/src/github,
# clones the given repo, and then cds into its directory
function ghc () {
  if [ $# -eq 0 ]; then
    url="$(xclip -out)"
    if [ $? -eq 0 ]; then
      se "No url given in cmd or on clipboard."
      return 1
    fi
  else
    url=$1
  fi
  gh
  gc $url

  f=$(echo "$url"|awk -F"/" '{print$NF}')
  if [[ $f == *".git" ]]; then
    f="${f%.*}"
  fi
  cd $f
}

function gits() {
  git status
}

function is_my_git_repo() {
  local dir="${1:-}"
  if [ -d "$(pwd)/${dir}" ]; then
    user=$(grep -A1 'remote "origin"' "$(pwd)/${dir}/.git/config" |\
      tail -n1| \
      awk -F':' '{print$2}'| \
      awk -F'/' '{print$1}')
    if [[ "$user" == "trustdarkness" ]]; then
      return 0
    fi
  fi
  return 1
}

 # super sudo, enables sudo like behavior with bash functions
function ssudo () {
  [[ "$(type -t $1)" == "function" ]] &&
    ARGS="$@" && sudo bash -c "$(declare -f $1); $ARGS"
}
alias ssudo="ssudo "

function is_alpha_char() {
  local string="${1:-}"
  if [ -n "$string" ] && [[ "$string" =~  [A-z] ]]; then
    return 0
  fi
  return 1
}

# To help common bash gotchas with [ -eq ], etc, this function simply
# takes something we hope to be an int (arg1) and returns 0 if it is
# 1 otherwise
function is_int() {
  local string="${1:-}"
  case $string in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
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
}

# Args: first term we hope is less than the second.
# returns 0 if it is, 1 otherwise. if first term is "", return 1
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
}

# Args: first term we hope is less than the second.
# returns 0 if it is, 1 otherwise. if first term is "", return 1
function le() {
  term1="${1:-}"
  term2="${2:-}"
  if is_int ${term1}; then
    if is_int ${term2}; then
      if [ ${term1} -le ${term2} ]; then
        return 0
      else
        return 1
      fi
    fi
  elif [[ "${term1}" == "" ]]; then
    return 1
  fi
}

function boolean_or {
  for b in "$@"; do
    # se "testing ${b}"
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

function sata_bus_scan() {
  sudo sh -c 'for i in $(seq 0 4); do echo "0 0 0" > /sys/class/scsi_host/host$i/scan; done'
}

function get_cache_for_OS () {
  case $(what_os) in
    'GNU/Linux')
      CACHE="$HOME/.local/cache"
      mkdir -p "$CACHE"
      OSUTIL="$D/linuxutil.sh"
      function sosutil() {
        source "$D/linuxutil.sh"
      }
      alias vosutil="vim $D/linuxutil.sh && sosutil"
      ;;
    "MacOS")
      CACHE="$HOME/Library/Application Support/Caches"
      OSUTIL="$D/macutil.sh"
      alias sosutil="source $D/macutil.sh"
      alias vosutil="vim $D/macutil.sh && vosutil"
      ;;
  esac
  export cache
}
get_cache_for_OS

function user_feedback() {
  local subject
  local message
  local detritus
  if [[ $# -gt 1 ]]; then
    subject="${1:-}"
    message="${2:-}"
    detritus="${@: 2}"
  else
    # https://askubuntu.com/questions/543553/write-to-syslog-from-the-command-line
    subject="${0##*/}[$$]"
    message="${1:-}"
  fi
  log_message() {
    if [[ "$subject" != "${0##*/}[$$]" ]]; then
      printf -v log "%s %s %s" "${0##*/}[$$]" "$subject" "$message"
    else
      printf -v log "%s %s" "$subject" "$message"
    fi
  }
  nix_notify() {
    if [[ $DISPLAY ]]; then
      if notify-send "$subject" "$messsage"; then
        return 0
      else
        errors+=("notify-send: $?")
      fi
    else
      log_message
      if $logger "$log"; then
        return 0
      else
        errors+=("$logger: $?")
      fi
    fi
  }
  bold=$(tput bold)
  normal=$(tput sgr0)
  declare -a errors
  case $- in
    *i*)
      printf "${bold}$subject${normal} -- $message"
      if [ -n "$detritus" ]; then printf "$detritus"; fi
      printf "\n"
      return 0
      ;;
    *)
      case $($what_os) in
        "GNU/Linux")
          logger=logger
          nix_notify
          ;;
        "MacOS")
          if [[ $(check_macos_gui) ]]; then
            printf -v applescripttext 'display notification %s with title %s' "$message" "$subject"
            if osascript -e "$applescripttext"; then
              return 0
            else
              errors+=("osascript: $?")
            fi
          else
            logger="syslog -s -l INFO"
            nix_notify
          fi
          ;;
      esac
      ;;
  esac
  declare -a meta_message
  meta_message+=("some attempts to notify the user may have failed")
  meta_message+=("original subject: $subject original message: $message errors: ${errors[@]}")
  se "${meta_message[@]}"
  $logger "${meta_message[@]}"
}

function osutil_load() {
  if [ -z "$osutil_in_env" ] || $osutil_in_env; then
    if [ -f "$OSUTIL" ]; then
      source "$OSUTIL"
      return 0
    else
      se "OS not properly detected or \$OSUTIL not found."
      return 1
    fi
  fi
}
osutil_load

alias sall="sbrc; sglobals; sutil; sosutil"

# initialized the helper library for the package installer
# for whatever the detected os environment is; good for interactive
# use below for scripts
function i() {
  source $D/installutil.sh
  return $?
}

function install_util_load() {
  if undefined "sai"; then
    source "$D/installutil.sh"
  fi
  i
  return $?
}
alias siu="source $D/installutil.sh"
alias viu="vim $D/installutil.sh && siu"

# so we dont load all that nonsense into the env, but the super
# frequently used ones remain readily available
if undefined "sai"; then
  sai() {
    unset -f sai sas sauu; i; sai "$@"
  }
  sas() {
    unset -f sai sas sauu; i; sas "$@"
  }
  sauu() {
    unset -f sai sas sauu; i; sauu "$@"
  }
fi

# for other files to avoid re-sourcing
UTILSH=true


_utilsh_fs() {
  declare -f
}