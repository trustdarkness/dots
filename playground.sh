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

    >2 printf 'previous: readonly %s=%s' "$name" "${!name}"
    >2 printf 'attempting:     ro %s=%s' "$name" "${val[@]}"

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
