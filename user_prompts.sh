#!/bin/bash
#
# Interactive, simple prompts that allow asking a user 
# if its ok to continue.  Slightly modified, but essentially
# as writtin on stackexchange were I found it in 2023. Any
# license concerns should be deferred to the original authors.
# If that's you, and you prefer I remove this code, please
# inform the repo author and I will do so as soon as I am 
# able.
#
# $Id$
# $Date$
# Expected location in production as $MTEBENV/.user_prompts
# based on .globals in this same directory.

# Read a single char from /dev/tty, prompting with "$*"
# Note: pressing enter will return a null string. Perhaps a version terminated with X and then remove it in caller?
# See https://unix.stackexchange.com/a/367880/143394 for dealing with multi-byte, etc.
function get_keypress {
  prompt="${1:-'something something give me a char'}"
  local IFS=
  >/dev/tty printf '%s' "${prompt}"
  # [[ $ZSH_VERSION ]] && read -rk1  # Use -u0 to read from STDIN
  # See https://unix.stackexchange.com/q/383197/143394 regarding '\n' -> ''
  [[ $BASH_VERSION ]] && </dev/tty read -rn1
  printf '%s' "$REPLY"
}
export -f get_keypress

# Get a y/n from the user, return yes=0, no=1 enter=$2
# Prompt using $1.
# If set, return $2 on pressing enter, useful for cancel or defualting
function get_yes_keypress {
  prompt="${1:-'Will it be y or n?'}"
  local enter_return=$2
  # [[ ! $prompt ]] && prompt="[y/n]? "
  while REPLY=$(get_keypress "$prompt"); do
    [[ $REPLY ]] && printf '\n' # $REPLY blank if user presses enter
    case "$REPLY" in
      Y|y)  return 0;;
      N|n)  return 1;;
      '')   [[ $enter_return ]] && return $enter_return
    esac
  done
}
export -f get_yes_keypress

# Prompt to confirm, defaulting to YES on <enter>
function confirm_yes {
  prompt="${1:-'Will it be y or n?'} [Y/n]? "
  return $(get_yes_keypress "$prompt" 0)
}
export -f confirm_yes

function confirm_yes_default_no() {
  userkey=$(get_keypress "${1:-(y/N)}")
  input_confirmed=false
  while ! $input_confirmed; do
    if ! [[ $userkey =~ Yy.* ]]; then 
      if [[ $userkey =~ Nn.* ]]; then 
        input_confirmed=true
        return 1 
      else
        echo "Please type Y or y to continue, N or n (or ctrl-c) will exit"
        userkey=$(get_keypress "continue? (y/N)")
      fi
    else
      input_confirmed=true
      return 0
    fi
  done
}

function get_timed_keypress {
  local IFS=
  >/dev/tty printf '%s' "$*"
  # [[ $ZSH_VERSION ]] && read -rk1  # Use -u0 to read from STDIN
  # See https://unix.stackexchange.com/q/383197/143394 regarding '\n' -> ''
  [[ $BASH_VERSION ]] && </dev/tty read -r -t7
  printf '%s' "$REPLY"
}

function get_timed_yes {
  local prompt="${1:-Are you sure}"
  local enter_return=$2
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
  local prompt="${*:-Are you sure [Y/n]? }"
  get_timed_yes "$prompt" 0
}

function timed_confirm_yes_default_no {
  local prompt="${*:-Are you sure [Y/n]? }"
  get_timed_yes "$prompt" 1
}

# See internal help
# TODO -- investigate uses, figure out if this is working, and/or
# delete or simplify
function choices() {
  help() {
    echo <<< EOF
    Usage: choices -[as] prompts_nameref \(optional\) actions_nameref

    Prompts the user with a list of choices and gets their response.

    Args:
      -a | --with-actions if specified, implies that the positional
                          nameref arg refers to an associative 
                          array where keys are prompts and vals
                          are eval'able actions to execute.  This 
                          function will execute the action on your
                          behalf in such cases.
      -s | --separator    nameref should generally be an array or 
                          associative array, but if needs be, a 
                          string is ok too, -s implies such and takes
                          an argument indicating the field separator,
                          defaults to \0, can be passed directly from
                          find -print0
      -c | --continue     add a continue option
      -e | --exit         add an exit option
      -r | --return       overrides exit and returns instead, text 
                          is the same \(exit to the user, but 
                          assuming were in a function not a script
                          we return)

      -h | -? | --help 		Prints this text.  

      the script will detect if the array is associative or not, and
      act accordingly.  If youre providing strings and theres a 
      second nameref, well assume its actions, separated by the same
      field separator.

      echos back and \(if possible\), returns the 0 indexed val of the
      user's choice \(even though the printed choices will be one
      indexed\).

      IMPORTANT: a return value of the length of your input +1 means
      continue, +2 means return -- if you sent -e, we will exit 0
      before you can catch the return \(suggest trapping\)
EOF
  }
  actions=false
  separator='\0'
  ucontinue=false
  ureturn=false
  uexit=false
  while [ $? -gt 0 ]; do 
    case "${1:-}" in
      'a'|'--with-actions')
        actions=true
        shift
        ;;
      's'|'--separator')
        separator="${2:-}"
        shift 
        shift
        ;;
      "-c"|"--continue")
        ucontinue=true
        shift
        ;;
      "-r"|"--return")
        ureturn=true
        shift
        ;;
      "-e"|"--exit")
        uexit=true
        shift
        ;;
      "-h"|"-?"|"--help")
        help
        shift
        ;;  
        *)
        help
        ;;
    esac
  done    
  local unknown="${1:-}"
  if [ -n "${unknown}" ]; then 
    declareopts=$(declare -p "${unknown}")
    se "declareopts: $declareopts unknown: $unknown"
    # TODO: how to handle -A
    if string_contains "\-a" "$declareopts"; then 
      prompts_name=$1[@]
      prompts_arr=("${!prompts_name}") # we know this is an array
    elif [ ${#unknown[@]} -eq 1 ]; then 
      # arg1 is a string
      prompts_arr=()
      prompts="${unknown}"
      printf -v s '%s' "${separator}"
      local IFS=$"$s"
      for prompt in "$prompts"; do 
        prompts_arr+=("$prompt")
      done
    fi
    pctr=0
    # TODO: stdout seems fucked here, so using stderr for ui
    # which is probably bad for whatever else that means.
    for prompt in "${prompts_arr[@]}"; do 
      ((pctr++))
      se "$pctr. $prompt"
    done
    if $ucontinue; then 
      ((pctr++))
      se "$pctr. Continue, doing nothing."
    fi     
    if boolean_or $uexit $ureturn; then
      ((pctr++))
      se "$pctr. Terminate execution and exit."
    fi
    set +x
      chosen=$(get_keypress "Enter choice 1.. ${pctr}: ")
      se " "
      actions="${2:-}"
      if [ -n "$actions" ]; then 
        local IFS=$"$s"
        actr=0
        completed=false
        for action in "$actions"; do 
          ((actr++))
          if [ $actr -eq $chosen ]; then
            eval "$action"
            completed=true
          fi
        done
        if ! $completed; then
          if $ucontinue; then 
            ((actr++))
            if [ $actr -eq $chosen ]; then 
              echo "$((actr-1))"
              return "$((actr-1))"
            fi
          fi
          if boolean_or $ureturn $uexit; then 
            ((actr++))
            if [ $actr -eq $chosen ]; then 
              if $uexit; then 
                exit 0;
              elif $ureturn; then 
                echo "$((actr-1))"
                return "$((actr-1))"
              fi # endif uexit
            fi # endif pctr = actr
          fi #endif boolean or
        fi # endif not completed
      fi # endif -n actions

  fi #endif unknown
  echo "$((chosen-1))"
  return "$((chosen-1))"
}