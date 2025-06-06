#!/usr/bin/env bash

declare -i EINVAL=22 # nvalid argument
declare -i EX_DATAERR=65 #data format error

# Comopsable, predictable bash version info, since we use >= bash 4.2
# features quite often and certain prominent POSIX OSs :cough: MacOS
# ship ancient ones
# no args, doesn't modify env or globals
# echos int, bash major version like 3, if bash is 3.2
# No explicit return code
function bash_major_version() {
  echo "${BASH_VERSINFO[0]}"
}

# no args, doesn't modify env or globals
# echos int, bash minor version like 2, if bash is 3.2
# No explicit return code
function bash_minor_version() {
  echo "${BASH_VERSINFO[1]}"
}

# no args, doesn't modify env or globals
# echos float, or string, this is bash, like 5.2
# No explicit return code
function bash_version() {
  major=$(bash_major_version)
  minor=$(bash_minor_version)
  echo "${major}.${minor}"
}

# kind of silly adaptation of
# https://www.cyberciti.biz/tips/bash-shell-parameter-substitution-2.html
# Args:
#   1 value to be repeated, this can be a string, variable, etc
#   2 (optional) int for how many times to repeat 1, defaults to 1
# echos arg1 repeated arg2 times
function repeat() {
  local to_repeat="${1?Error please supply a value to be repeated}"
  local times="${2:-1}"
	for i in $(seq 0 ${times}); do echo -n "${to_repeat} "; done
}

########################## DECLARE AND UNDECLARE ##############################
# Since comments are also extra storage for the brain, if we're going to do
# crazy stuff, lets remind ourselves of the fundamentals.  declare opts:
#  -a   array
#  -A   associative array
#  -f   function name
#  -F   function name and attributes (implies -f)
#  -g   force declaration in a function to be global
#       It is ignored in all other cases.
#  -i   integer; arithmetic evaluation (see Shell Arithmetic)
#  -I   Cause local variables to inherit the attributes (except the nameref
#       attribute) and value of any existing variable with the same name at a
#       surrounding scope. If there is no existing variable, the local variable
#       is initially unset.
#  -l   When the variable is assigned a value, upper-case characters are
#       converted to lower-case. The upper-case attribute is disabled.
# -n    Give each name the nameref attribute, making
#       it a name reference to another variable. That other variable is defined
#       by the value of name. All references, assignments, and attribute
#       modifications to name, except for those using or changing the -n
#       attribute itself, are performed on the variable referenced by name’s
#       value. The nameref attribute cannot be applied to array variables.
# -p    Display attributes values of each name
#       * with name arguments, options other than -f and -F, are ignored.
#       * without name arguments, declare will display the attributes and values
#       of all variables  matching other options.
#       * If no other options are supplied with -p,will display attributes and
#       values of all shell variables. -f will restrict to functions.
# -r   Make names readonly.
# -t   Give each name the trace attribute.
#      Traced functions inherit the DEBUG and RETURN traps from the calling
#      shell. The trace attribute has no special meaning for variables.
# -u   all lower-case characters are converted to upper-case.
#      The lower-case attribute is disabled.
# -x   Mark each name for export to subsequent commands via the environment.

N="Requires variable name (not the var itself) as argument %d"
V="Requires variable as argument %d"
R="Requires regex as argument %d"

# Args:
#   1 the name of a variable or function that might exist
# Returns the return value from declare -p or -f,
#   0 if there is a named var or function, 1 if not
function is_declared() {
  local nameerror
  printf -v nameerror "$N" 1
  declare -p ${1?"$nameerror"} > /dev/null 2>&1|| \
    declare -f ${1?"$nameerror"} > /dev/null 2>&1
  return $?
}

# A slightly more convenient and less tedious way to print
# to stderr, normally declared in util.sh, sourced from .bashrc
if ! is_declared "se"; then
  # Args:
  #  -u - do not add a newline when printing, similar to one of the use
  #       cases for printf vs echo.
  #
  #  Otherwise, se echoes to stderr anything it recieves, and If theres
  #  no newline in the input, it is added. if there are substitutions
  #  for printf in $1, then $1 is treated as format string and
  #  $:2 are treated as substitutions.  se replaces any literal '-' with
  # '\x2D', the hex char code for '-' otherwise there are cases where
  # printf will try to interpret these as flags.
  # No explicit return code
  function se() {
    local nonewline
    nonewline=false
    if [[ "${1:-}" == "-u" ]]; then
      nonewline=true
      shift
    fi
    if [[ "$*" == *'%'* ]]; then
      sub="${@:2}"
      # if the provided string contains a '-' in the first column, printf
      # will try to interpret it as a command line flag
      if ! >&2 printf "${1:-/'-'/'\x2D'}" "${sub/'-'/'\x2D'}"; then
        return "$EINVAL"
      fi
    else
      if [ -n "$*" ]; then # like echo, sometimes se is used just to emit \n
        if ! >&2 printf "${@/'-'/'\x2D' }"; then
          return 1
        fi
      fi
    fi
    if untru "$nonewline"; then
      if [[ "$*" != *$'\n'* ]]; then # match on the ANSI Cstring
        if ! >&2 printf '\n'; then
          return 1
        fi
      fi
    fi
  }
fi

# Args:
#   1 the name of a variable or function that might exist
#
# Returns 0 if some version of this name exists within the
#   environment, shell declarations and builtins, system PATH,
#   etc. Returns 1 if nothing seems to be using the name.
#
# If it finds anything in env that doesnt seem to be an
# explicit assignment, it will print more information to
# stderr and return 1
function exists() {
  local nameerror
  printf -v nameerror "$N" 1
  local name="${1?$nameerror}"
  if is_declared "$name" > /dev/null 2>&1; then return 0; fi
  if type -p "$name" > /dev/null 2>&1; then return 0; fi
  # above should cover everything(ish), but just in case
  if [ -z "$name" ]; then
    return 1
  fi
  env_hits=$(env |grep "$name")
  if [ $? -eq 0 ]; then
    env_def=$(grep "${name}=" <<< "$env_hits")
    if [ $? -gt 0 ]; then
      se "This was discovered in the working environment,"
      se "It does not seem to be a namespace declaration."
      se "$env_hits" # bet the oval office probly listen to fugazi
      return 1
    fi
  fi
  return 1
}

function isset() {
  var="${1:-}"
  if [ ${#var} -eq 0 ]; then
    return 1
  elif [ -n "${1:-}" ]; then
    return 0
  fi
  return 1
}

function isntset() {
  if [ -z "${1:-}" ]; then
    return 0
  fi
  return 1
}

function empty() { # for all you androids who can't use contractions
  isntset "${1:-}"
}

# excessive use of negations makes code messy and readability
# more difficult. hence the convenience wrapper.
# Args: name to check if exists in the namespace
# returns 0 if name is undefined or not findable in the PATH, shell, or env
# 1 otherwise
function undefined() {
  local nameerror
  printf -v nameerror "$N" 1
  local name="${1?$nameerror}"
  if exists "${name}"; then
    return 1
  fi
  return 0
}

# To make operation on booleans slightly more readable and less error
# prone.  Returns zero if the arg is a variable that exists and is
# set to "true" or the corresponding commannd, If the output of a command
# is given to its standard in, that can create a situation where we're
# evaluating whether programX completed properly. That results in the
# situation that may feel strange to those whove written code elsewhere
# and might expect true=1, but in bash you'll notice even hte booleans
# 'true' and 'false' are commands themselves, where true returns 0 and
# false 1.  1 otherwise
function tru() {
  is_it="${1:-}"
  if [ -n "${is_it}" ]; then
    if [[ "${is_it}" =~ true|false ]]; then
      if "${is_it}"; then
        return 0
      fi
    elif is_int ${is_it} && [ $is_it -eq 0 ]; then
      return 0
    fi
  fi
  return 1
}

function untru() {
  it_isnt="${1:-}"
  if is_int ${it_isnt}; then
    if [ ${it_isnt} -eq 0 ]; then # because its bash 0 == true
      return 1
    fi
  elif [[ "${it_isnt}" == "true" ]]; then
    return 1
  fi
  # we want to default to an object being false unless its explicitly
  # 0 or true
  return 0
}

# Use grep to check how a name was declared using a provided regex
# Args:
#   1 the declared nasyntax error: operand expected me to check
#   2 the regex to check against
# returns the ret code from grep
function search_declareopts() {
  local nameerror
  printf -v nameerror "$N" 1
  local -n name=${1?"$nameerror"}
  local regexerror
  printf -v regexerror "$R" 2
  local regex=${2:?"$regexerror"}
  declareopts=$(declare -p $name)
  grep -E "${regex}" <<< "${declareopts}" > /dev/null 2>&1
  return $?
}

VALID_DECLARE_FLAGS='aAfFgiIlnrtux'
printf -v IS_READONLY_REGEX '\-[%s]*r[%s]*' $(repeat "${VALID_DECLARE_FLAGS}")

# Args:
#   1 the name of a variable or function that hopefully exists
# Returns 0 if the name was declared with -r, 1 otherwise
function is_readonly() {
  search_declareopts "${1:-}" "${IS_READONLY_REGEX}"
  return $?
}

# try to limit the damage we might do with this particular one down the line
# by defining undeclareable as arrays or global variables declared as
# readonly uppercase
VALID_UNDECLARE_FLAGS='aAxg'
printf -v IS_UNDECLAREABLE_REGEX '\-[%s]*(ur|ru)[%s]*' \
  $(repeat "${VALID_UNDECLARE_FLAGS}")

# Args:
#   1 the name of a variable or function that hopefully exists
# Returns 0 if the name seems safe to force undeclare, this is a subset
#   of readonly as defined above, basically arrays and all caps
#   global variables.  Exercising exessive caution.
function is_undeclareable() {
  search_declareopts "${1:-}" "${IS_UNDECLAREABLE_REGEX}"
  return $?
}

# an array will be created with declare -A or -a but may come
# with other valid flags at creation.  We'd like to detect whether
# a given variable reference is an associative array in a stable
# and consistent manner with grep
VALID_ARRAY_FLAGS='glrux'
printf -v IS_A_ARRAY_REGEX '\-[%s]*A[%s]*' $(repeat "${VALID_ARRAY_FLAGS}")
printf -v IS_ARRAY_REGEX '\-[%s]*a[%s]*' $(repeat "${VALID_ARRAY_FLAGS}")

# Args:
#   1 the name of a variable or function that hopefully exists
# Returns 0 if the name is an associative array, 1 otherwise
function is_A_array() {
  search_declareopts "${1:-}" "${IS_A_ARRAY_REGEX}"
  return $?
}

# Args:
#   1 the name of a variable or function that hopefully exists
# Returns 0 if the name is an indexed array, 1 otherwise
function is_array() {
  search_declareopts "${1:-}" "${IS_ARRAY_REGEX}"
  return $?
} # end is_array

NAMEREFS_EXISTENCE=('is_array')
