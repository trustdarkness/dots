function make_pipes() {
  pipestring="${1:-}"
  set -x
  function cleanup() {
    rm -f /tmp/nfifo*
  }
  trap cleanup EXIT INT KILL

  if [ -n "${pipestring}" ] ; then
    if ! [[ "${pipestring}" == *'|'* ]]; then
      se "please provide your set of piped commands as a single string, pipes included"
    fi
  else
     se "please provide your set of piped commands as a single string, pipes included"
  fi
  readarray -d"|" local_commands < <(echo "${pipestring}")
  ctr=0
  last_command=$#
  for command in "${local_commands[@]}"; do
    mkfifo /tmp/nfifo${ctr}
    readarray -d" " components < <(echo "${command}"| sed 's/|//')
    case ${ctr} in
      0)
        (
          ${components[@]} > /tmp/nfifo${ctr} &
        )
        ;;
      ${last_command})
        (
          output=$(${components[@]} < /tmp/nfifo$((ctr-1))) &
        )
        ;;
      *)
        (
          ${components[@]} < /tmp/nfifo$((ctr-1)) > /tmp/nfifo${ctr} &
        )
        ;;
    esac
    ((ctr++))
  done
  if [ -n "${output}" ]; then
    echo "${output}"
  fi
  if gt ${ret} 0; then
    return ${ret}
  fi
  return ${ret}
}

# Args:
#   1 name to use
#   2 value(s) to assign
# tries to function as much like a traditional assignment as possible
# so assign foo bar will work just like foo=bar
# assign foo "${bar[@]}" will work like foo=( "${bar[@]}" )
# and assign foo bar1 bar2 bar3 will work like foo=( bar1 bar2 bar3 )
# no explicit return value
function assign() {
  local nameerror
  printf -v nameerror "$N" 1
  local -n name=${1?"$nameerror"}
  shift
  local valerror
  printf -v valerror "$V" 2
  local val=${2?$valerror}
  if [ $# -gt 1 ]; then
    name=( $@ )
  else
    name="$val"
  fi
} # end assign


# attempts to work much like the readonly keyword wrapping the above
# assign function, its arguments are the same, only ro will try to
# ubind the variable if its currently readonly.  It will take extreme
# measures (attaching gdb and unbinding) if arg2 (so between the name)
# and whatever assignees) is the word "force."
#
# if ro name val(s) is the same as the existing environment, we do
# nothing and return 0.  if name doesn't exist, we run
# readonly name=val and we return 0.
#
# if DEBUG=true in the env, additional information will be printed to
# stderr.
function ro() {
  local nameerror
  printf -v nameerror "$N" 1
  local -n name=${1?"$nameerror"}
  shift
  force_attempt=false # default
  # because I'm insane, we're going to allow this, but because I'm cautious
  # we're only going to allow it within the scope of creating a readonly
  # variable or trying to reassign one, and then only if the user has
  # gone out of their way to be explicit by passing "force" into ro
  # undeclare itself takes:
  # Args:
  #  1 a declared name to try to force undeclare
  # caution, and/or copypasta later, we try unset first, then declare +r, if
  # both fail, we attach gdb and unbind the variable.
  # if DEBUG is set to true in the env, it will print which method succeeded
  # and return 0 on success, otherwise returns 1
  function undeclare() {
    local nameerror
    printf -v nameerror "$N" 1
    local -n name=${1?"$nameerror"}
    declare +r $name > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      if $DEBUG; then se "made %s writeable via %s" $name !:*; fi
      return 0
    fi
    unset "$1" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      if $DEBUG; then se "made %s writeable via %s" $name !:*; fi
      return 0
    fi
    gdb -q -n <<EOF > /dev/null 2>&1
attach $$
call unbind_variable("$name")
detach
quit
EOF
    if [ $? -eq 0 ]; then
      if $DEBUG; then se "made %s writeable via %s" $name !:*; fi
      return 0
    fi
    return 1
  } # end undeclare

  # Args:
  #  the val assignment for the outer function, so either ${@:2}
  #  or ${@:3} following the force keyword
  # runs assign to assign name to $@, makes name readonly and returns 0
  # on success.
  function do_ro() {
    if [ -n "${name}" ] && [ -n "${kwargs}" ]; then
      assign "$name" ${kwargs[@]}
      readonly "$name"
      return 0
    fi
    return 1
  } #end do_ro
  if [[ "$1" == "force" ]];  then
    force_attempt=true
    shift
  else # $@ is whatever assignments the caller
        # intended to make
    if [ $# -gt 1 ]; then
      vals=( "$@" )
    else
      vals="$@"
    fi
  fi

  if ! is_readonly $name; then
    $name="${vals[@]}"
    return 0
  else
    if [[ "${!name}" == "${val[@]}" ]]; then
      # old val and new val are the same, nothing to do here
      return 0
    fi
    writeable=false
    reassign=true

    >&2 printf 'previous: readonly %s=%s' "$name" "${!name}"
    >&2 printf 'attempting:     ro %s=%s' "$name" "${val[@]}"

    if force_attempt=true; then
      if is_undeclareable $name; then
        if ! $writeable; then
          if undeclare $name; then
            writeable=true
            return $(do_ro)
          else
            return 1
          fi
        fi # end if not writeable undeclare
      fi # end if undeclare
    fi # end if force
  fi # end is readonly
}

# NOT currently working
# function show_global_scope_declares() {
#   script="${1:-}"
#   if is_bash_script "script"; then
#     declare -a ifs
#     declare -a fis
#     declare -a fors
#     declare -a whiles
#     declare -a dones
#     for lineno in $(grep -n ^if "$script"|awk -F":" '{print$1}'); do
#       ifs+=( $lineno )
#     done
#     for lineno in "${ifs[@]}"; do
#       fis+=( $(tail -n $lineno "$script" |grep ^fi |head -n 1| awk -F":" '{print$1}') )
#     done
#     for lineno in $(grep -n ^for "$script"|awk -F":" '{print$1}'); do
#       fors+=( $lineno )
#     done
#     for lineno in "${fors[@]}"; do
#       dones+=( $(tail -n $lineno "$script" |grep ^done |head -n 1| awk -F":" '{print$1}') )
#     done
#     ifctr=0
#     forctr=0
#     for line in $(grep -E -v '(^[[:space:]]|^}|^done|^END|^#|^EOF)' "$script"); do
#       case "$(echo line|awk '{print$1}')" in
#         "if")
#           cat "$script" | head -n "${ifs[$ifctr]}" | tail -n "${fis[$ifctr]}"
#           ((ifctr++))
#           ;;
#         "for")
#           cat "$script" | head -n "${fors[$forctr]}" | tail -n "${dones[$forctr]}"
#           ((forctr++))
#           ;;
#         *)
#           echo $line
#           ;;
#       esac
#     done
#   fi
# }

function compgenv() {
  for name in $(compgen -v); do
     printf "%s=%s\n" "$name" "${!name}"
  done
  return 0
}

alias alias_print='alias | sed "s/alias //g'

function declare_to_jqconst() {
  local declarecmd="${1:-}"
  local _const=''
  for declare in $($declarecmd); do
    local nameeqval="${declare:${#declarecmd}+1}"
    local name=$(echo "$nameeqval"|cut -d "=" -f1)
    local -n arr="$name"
    _const+="$(printf '\x2D\x2Darg "%s" ' "$name")"
    if [[ "$declarecmd" =~ .*\-a|A ]] && [ "${#arr[@]}" -gt 1 ]; then
      _const+="$(printf '[ ')"
      for val in "${arr[@]}"; do
        _const+='"%s", ' "$val"
      done
      _const+='] \\'
      _const+="
"
    fi
  done
  echo "$_const"; return 0
}

function setoposix_to_jqconst() {
  names=(); vals=();
  (set -o posix; set) | while IFS=$'\n' read -r line; do
    names+=( $(echo "$line" | cut -d"=" -f1) )
    val=$(echo "$line" | cut -d"=" -f2)
    if [[ "$val" =~ ^\(.*\=.* ]] then
      local -n arr="$name"
      l='[ '
      for name in "${arr[@]}"; do
        l+=$(printf '"%s", ' "$name")
      done
      l+=' ]'
      vals+=( "$l" )
    else
      vals+=( "$val" )
    fi
  done
  local _const=""; local i=0
  for name in "${names[@]}"; do
    _const+="$(printf '\x2D\x2Darg "%s" "%s" ' "$name" "${vals[$i]}")"
    _const+="$(printf "'%s' \\" "\$ARGS.named")"
    _const+="
"
    ((i++))
  done
}

IFS='' read -r -d '' ENVINFO <<EOF
jo filename=".local_lhrc" \
   BASH_SOURCE="${BASH_SOURCE[*]}" \
   FUNCNAME="${FUNCNAME[*]}"
EOF
#   compgen_a
   # $(vargen_to_jqconst 'compgen -a') '\$ARGS.named')" \
#   --arg 'compgen -v' "$(jq -n $(vargen_to_jqconst 'compgen -v') '\$ARGS.named')" \
#   --arg 'compgen -e' "$(jq -n $(vargen_to_jqconst 'compgen -e') '\$ARGS.named')" \
#   --arg 'declare -a' "$(jq -n $(declare_to_jqconst 'declare -a') '\$ARGS.named')" \
#   --arg 'declare -A' "$(jq -n $(declare_to_jqconst 'declare -A') '\$ARGS.named')" \
#   --arg 'declare -F' "$(jq -n $(declare_to_jqconst 'declare -F') '\$ARGS.named')" \
#   --arg 'set -o posix; set' "$(jq -n $(setoposix_to_jqconst) '\$ARGS.named')"
# EOF

# depends
# - existence.sh
#  * undefined
# - filesystemarrayutil.sh
#  * in_array
function namerefs_bashscript_add() {
  script="${1:-}"
  if ! is_bash_script; then
    se "please provide a path to a bash script"
  fi
  # our main container for names
  declare -ga _names

  # case: global function names
  _names=$(function_finder "$script")

  # get variables declared as local for exclusion (this may result in false positives)
  declare -ga localvars
  declare -a localvarlines
  printf -v sedstr 's/%s/One: \\1/g' "$BASH_LOCAL_VAR_SED_EXTRACT_NAME2_REGEX"
  while IFS= read -r matchedline; do
    # printf "($matchedline) "
    lname=$(echo "$matchedline"| sed 's/.*local//g'| # remove local
                                        sed 's/-[A-z]//g') # remove any flags
    if [[ "$lname" == *'='* ]]; then
      lname=$(echo "$lname" | cut -d'=' -f1)
    fi
    localvars+=( "$lname" )
  done < <(pcre2grep --null "$BASH_LOCAL_VAR_PCREREGEX" "$script")
  # localvarlines=( $(grep '^[[:space:]]*local[[:space:]]*[[-][[:alpha:]]]*[[:space:]]*[[[:alnum:]][_]]*' "$script") )
  # for line in "${localvarlines[@]}"; do
  #   wequal=$(echo "$line"|grep "=")
  #   if [ $? -eq 0 ]; then
  #     # we're expecting something like "local foo=bar" and we want foo
  #     localvars+=( $(echo "$wequal" | awk '{print$1}' |awk -F'=' '{print$1}') )
  #   else
  #     localvars+=( $(echo "$line" | awk '{print$2}') )
  #   fi
  # done

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
  existing_namerefs="$(grep -E '^NAMEREFS_[A-z]+\=\(.*\)$' "${script}")"
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
  local -n script_namerefs="$expected_name"

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
  sed -ri.bak 's/^NAMEREFS_[A-z]+\=\(.*\)$//g' "$script"
  # add it in a nice-to-look-at format:
  printf "\n\n${expected_name}=(" >> "$script"
  for quoted_nameref in "${out_namerefs[@]}"; do
    printf "$quoted_nameref" >> "$script"
  done
  printf ")\n" >> "$script"
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



function strict_mode_set() {

  exit_handler() {
    retval="${1:-}"
    lineno="${2:-}"
    shift; shift # the remainder of args are source files or function names
    se "exit caught."
    return
  }

  # using this within the context of running functions in an
  # interactive shell will cause you to lose your shell in a way
  # that is unconducive to a productive working environment
  trap 'exit_handler $? $LINENO ${BASH_SOURCE[*]} ${FUNCNAME[*]}' EXIT
  declare -gA SAVED_SET_OPTS
  local opts_to_save=( "errexit" "nounset" "pipefail" )
  # get current status of relevant opts
  while IFS=$'\n' read -r line; do
    for opt in "${opts_to_save[@]}"; do
      if [[ "$line" =~ $opt[:space:]([:alnum:]) ]]; then
        SAVED_SET_OPTS[$opt]="${BASH_REMATCH[1]}"
      fi
    done
  done < <(set -o)
  set -euo pipefail
}

function unset_strict() {
  for opt in "${!SAVED_SET_OPTS[@]}"; do
    if [[ "${SAVED_SET_OPTS[$opt]}" == "off" ]]; then
      set +o $opt
    else
      set -o $opt
    fi
  done
}

function gpgvc() {
  gpg --verify < <(xclip -o)
  return $?
}

function gpgic() {
  gpg --import < <(xclip -o)
  return $?
}
