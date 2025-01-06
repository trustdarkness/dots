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


PCRE_SINGLE_LINE='(?s)'
PCRE_NO_SINGLE_LINE='(?-s)'

function_match_pcre() {
  function_name="${1:-}"
  # we're going to assemble this piece by piece, first characters we expect
  # inside a function without problematic escapes (noe); without close braces
  # no brackets, and for now we're thinking about only a single line, and
  # only possible individual characters
  local inner_noe_nob='A-z0-9\*_\,\s;=+!&\/\.%@:\\\h\(\)\{'
  # add problematic chars to properly escape
  printf -v inner_nob '%s%s%s%s' "$inner_noe_nob" "\'" '\"' '-'
  # in c, we expect the function definition to have params and types, which
  # aside from the enclosing parents, should be covered by above, so lets
  # assemble the function definition.  We're going to ignore the type/return.
  printf -v fdef '%s\h*\([%s]*\)\s*\{' "$function_name" "$inner_nob"
  # we're going to ignore any possibility of braces inside the function body
  # atm focusing on c functions... this is not feasible for bash TODO

  # now we're going to make that a character class
  printf -v fn_line_class '[%s]' "$inner_nob"

  # and we'll say on any given line we can have that repeated character
  # class or we can have a close brace with anything in front of it
  # except a newline, which we're hoping can always mean the end of the
  # function, and a silly three function
  three=(a b c)
  printf -v fn_line_or_cbrace '%s*|%s+}%s*' $(echo ${three[@]/*/"$fn_line_class"})
  # and then we're going to nest that character class (a line) into
  # a larger character class containing newlines and making the function body
  # and repeat that character class -- \v is vertical tab in printf but we
  # want vertical whitespace in regex, so we double escape
  printf -v fn_class '[%s\\v]*' "$fn_line_or_cbrace"
  # how we find the end of the function
  printf -v fterminate '^\}$'
  # now assemble it all in the proper order
  fn_components_for_pcre=(
    "$fdef"
    "$fn_class"
    "$fterminate"
  )
  # now assemble it in a single string var
  printf -v raw_fn_pcre '%s' "${fn_components_for_pcre[@]}"
  # and surround it in single quotes
  quoted_fn_pcre=$(singlequote "$raw_fn_pcre")
  # because there's a single quote inside the single quotes, we need to give it
  # to whoever's using it as an ansi c string
  echo "\$$quoted_fn_pcre"
  return $?
}

# ignores network shares. "L" for local.
function lfind_args() {


  # we delineate argv as
  #       0    1    2       3             4
  # Linux find $dir -mount  $otherargs...
  # Mac   find $dir -fstype local         $otherargs....
  # we will drop arg0 when calling find, but leave it for env record keeping
  LFIND_RUN+=( "find" )
  case $(what_os) in
    "MacOS")
      LFIND_RUN+=( "-fstype" )
      LFIND_RUN+=( "local" )
      ;;
    'GNU/Linux')
      LFIND_RUN+=( "-mount" )
      ;;
  esac
  LFIND_RUN+=( "find" )
  LFIND_RUN+=( "${LFIND_IN[1]}" )
  LFIND_RUN+=( "${argv2[@]}" )
  if gt $# 2; then
    LFIND_RUN+=( "${LFIND_IN[@]:2}" )
  fi

  echo "${LFIND_RUN[@]:1}"
  return 0
}

function lfind() {
  declare -ga LFIND_IN
  declare -ga LFIND_RUN
  declare -ga LFIND_STACK
  LFIND_STACK=( "${FUNCNAME[@]}" )
  LFIND_IN=( "$@" )
  if to_compose_str=$(find_composed_of); then
    composed=true
  fi
  lfind_args "$@"
  if $composed; then
    compose_find "${to_compose[@]}"
    return $?
  fi
  find "${LFIND_RUN[@]}"
}

# clear find, do not print stderr to the console.
# stderr can be found at $CACHE/cfind/last_stderr
# we also save the previous at $CACHE/cfind/last_last_stderr
# but no more silliness beyond that
# where $CACHE is ~/.local/cache on Linux and
# ~/Library/Application\ Support/Caches on Mac
function cfind_args() {
  mkdir -p "$CACHE/cfind"
  errfile="$CACHE/cfind/last_stderr"
  prev_errfile="$CACHE/cfind/last_last_stderr"
  if [ -f "$prev_errfile" ]; then
    rm -f "$prev_errfile"
  fi
  if [ -f "$errfile" ]; then
    mv "$errfile" "$prev_errfile"
  fi
  CFIND_RUN=( "find" "${CFIND_IN[@]}" "2>" "$errfile" )
  if $composed; then
    compose_find "$to_compose_str"
    return $?
  fi
  find "${CFIND_RUN[@]:1}"
  return $?
}

function cfind() {
  declare -ga CFIND_IN
  declare -ga CFIND_RUN
  declare -ga CFIND_STACK
  composed=false
  CFIND_STACK=( "${FUNCNAME[@]}" )
  CFIND_IN=( "$@" )
  if to_compose_str=$(find_composed_of); then
    composed=true
  fi
  cfind_args "$@"
  if $composed; then
    compose_find "${to_compose[@]}"
    return $?
  fi
  find "${CFIND_RUN[@]}"
}

# now we can define silly things like
function clfind() {
 cfind lfind "$@"
}


version_string_valid() {
  [[ $versionNumber =~ ^[0-9]+\.[0-9]+ ]] && echo "${BASH_REMATCH[0]}" 
}

IntegerMatrix() {
  name=
  dimensions=

  optspec="n:d:h"
  unset OPTIND
  unset optchar
  while getopts "${optspec}" optchar; do

    case "${optchar}" in
      n)
        name="${OPTARG}"
        ;;
      d) 
        [[ "${OPTARG}" =~ [^0-9]{,2}[x|X][0-9]{,2}$ ]] && dimensions="${OPTARG}" || usage; return 1
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
  rows=$(echo "${dimensions,,}" | cut -d "x" -f 1)
  cols=$(echo "${dimensions,,}" | cut -d "x" -f 2)
  local colctr=0
  local rowctr=0
  declare -ga "$name"
  local -n matrix="$name"
  matrix=()

  declare -a a
  a=()
  for x in {a..z}; do 
    a+=("$x")
  done
  # start row 0
  row="$1"
  ((colctr++))
  shift
  local ingested=1
  local startnextrow
  for i in "$@"; do 
    if [ $colctr -lt $cols ]; then
      if ! is_int "$i"; then 
        error "only integer values supported"
        return 1
      fi
      printf -v row "%s%s%s" "$row" "${a[$rowctr]}" "$i"
      ((ingested++))
      ((colctr++))
    else
      colctr=0
      startnextrow="$ingested"
      row=" "
    fi
  done

}

_tracing_arrays() {
  cat <<-'EOF'
    i=0;
    for src in "${BASH_SOURCE[@]}"; do
      bn=$(basename "$src");
      if [ "$i" -eq 0 ]; then tagnum="${i}"; 
      elif [ "$i" -ge 1 ]; then tagnum=$((i+1)); fi;
      declare -gn sout="s${tagnum}";
      printf -v "s${tagnum}" "%*s%s " "${tagnum}" "⎯" "$src";
      if [ $i -gt 1 ]; then 
        declare -gn fout="f${i}";
        declare -gn lout="l${i}";
        printf -v "f${i}" "%s%*s[%s] %s:%s " "\" "$((i))" "_" 
          "${FUNCNAME[$tagnum]}" "$src" "${BASH_LINENO[$i]}"; 
      fi;
      ((i++));
    done;
EOF
  # TODO: print header nums
  for j in $(seq 0 $i); do 
    local -n sspace="slen${j}"
    local -n sout="s${i}"
    s="${!sout}"
    if [ -n "${s}" ]; then 
      printf "0.${s}"
    fi
  done
  for j in $(seq 0 $i); do 
    local fltag=$((j+1))
    local -n fspace="f$fltag"
    local -n lspace="l$fltag"
    local -n fout="f${fltag}"
    local -n lout="l${fltag}"
    f="${!fout}"
    l="${!lout}"
    printf "${f}: ${l}"

    if [ $j -ge 1 ] && [ $j -le $i ]; then 
      tagnum=$((j+1))
      local -n soldout="s${oldtag}"
      local -n sthissout="${tagnum}"
      # if [ "${#oldout}" -eq "${#thisout}" ];
      printf "${!sout}"
    fi
  done
}
alias trace-arrays='eval $(_tracing_arrays)'



and_or_tester() {
  local vals="$1 $2"
  [[ $1 && $2 ]]; dse "${vals}true" && return 0 
  error "${vals}false" && return 66
}

and_or_tests() {
truthtable=("0 0" "0 1" "1 0" "1 1")
for row in "${truthtable[@]}"; do and_or_tester $row; done
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