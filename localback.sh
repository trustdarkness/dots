# Temporary for machine rebuild
export OLDHOME="/CityInFlames/mt"
export OLDETC="/CityInFlames/etc"

function restore() {
  global=0
  LOC=$1
  merge=0
  etc=0
  help () {
    echo "A simple wrapper function to restore from a backup dir on a"
    echo "fresh install.  Default is to replace existing items, creating"
    echo "a backup.  We can also merge/update."
    echo " " 
    echo "To work properly the following vars must be set to paths"
    echo "containing data to be restored:"
    echo " - OLDHOME, user files organized as they should be pulled into"
    echo "            the new system."
    # echo " - OLDSYS, files and software from outside the users homedir,"
    # echo "           activated by using the -n (nonpersonalized) flag."
    echo " - OLDETC, location of previous etc, will ask for sudo"
    echo " "
    # echo "-n is for non-personalized software from a local source"
    # echo "   but still restored to \$HOME."
    echo "-e will restore from OLDETC, will ask for sudo"
    echo "-m will merge/update existing files"
  }
  our_copy() {
    s="${1:-}"
    d="${2:-}"
    if ! is_function can_i_write; then
      util_env_load -f
    fi 
    if can_i_write "$d"; then 
      cp -avr "$s" "$d"
      ret=$?
    else
      if confirm_yes "$(whoami) can't write to $d, use sudo?"; then 
        sudo cp -avr "$s" "$d"
        ret=$?
      else
        echo "exiting."
        ret=1
      fi
    fi
    return $ret
  }

  do_restore() {
    LOC="${1:-}"
    if [ $global -eq 1 ]; then 
      BK="${OLDSYS}"
    elif [ $etc -eq 1 ]; then
      BK="${OLDETC}"
    else
      BK="${OLDHOME}"
    fi
    if ! [ -e "$BK/${loc}" ]; then
      >&2 printf "could not find original at $BK/$loc"
      return 1
    fi
    new="$BK/$LOC"
    if [ $global -eq 0 ] && [ $etc -eq 0 ]; then 
      old="$HOME/$LOC"
      prerestorebak="$HOME/.bak"
    elif [ $etc -eq 1 ]; then 
      old="/etc/$LOC"
      prerestorebak="$HOME/.etcprerestorebak"
    fi  
    if [ $merge -ne 1 ]; then
      if [ -d "$BK" ]; then
        if stringContains "/" "$LOC"; then
          dn=$(dirname "$LOC")
          if ! [ -d "$HOME/$dn" ]; then
            echo "to restore $LOC, i need to mkdir -p $HOME/$dn"
            yn=$(confirm_yes "OK (Y/n?)")
            if [ $? -eq 0 ]; then
              mkdir -p "$HOME/$dn"
            else
              return 1
            fi
          fi
        fi

        mkdir -p "$prerestorebak"
        old_parent=$(dirname "$old")
        confirm_yes "restoring $new to $old_parent... ok?"
        echo
        if [ -d "$old" ]; then 
          echo "Backing up existing $old to .bak"
          if ! our_copy "$old" "$prerestorebak"; then
            return $?
          fi
        fi
        
        our_copy "$new" "$old_parent"
        return $?
      else
        se "Didn't find a backup directory at $BK. exiting."
        return 1
      fi
    else
      confirm_yes "merging $new to $old if it exists... ok?"
      rsync -rlutv "$new" "$old"
      return $?
    fi
  }


  
  args=$(getopt -o nemch --long nonpersonalized,etc,merge,help -- "$@")
  if [[ $? -gt 0 ]]; then
    help
  fi
  local POSITIONAL_ARGS=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      -n|--nonpersonalized)
        global=1
        shift 
        ;;
      -m|--merge)
        merge=1
        shift
        ;;
      -e|--etc)
        etc=1
        shift
        ;;
      -h|--help)
        help
        return 1
        ;;
      *)
        POSITIONAL_ARGS+=("${1-}")
        shift
        ;;

    esac
  done
  set -- ${POSITIONAL_ARGS[@]+"${POSITIONAL_ARGS[@]}"}
  failures=0

  if ! declare -F "confirm_yes" > /dev/null 2>&1; then 
    source "$D/user_prompts.sh"
  fi
  if [ -z "$OLDHOME" ]; then 
    echo "Please export OLDHOME=/path/to/pold/homedir"
    return 1
  fi

  for loc in "${POSITIONAL_ARGS[@]}"; do
    if ! do_restore "${loc}"; then 
        ((failures++))
    fi
  done
  return ${failures}
}

_restore_autocomplete() {
  local cur
  cur=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=( $(compgen -f $OLDHOME/$cur | cut -d"/" -f5 ) )
}
complete -o filenames -F _restore_autocomplete restore

function lsbke() {
  ls "${OLDETC}"/"${1:-}"
}

_lsbke_autocomplete() {
  local cur
  cur=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=( $(compgen -f ${OLDETC}/$cur | cut -d"/" -f5 ) )
}
complete -o filenames -F _lsbke_autocomplete lsbke

function lsbkh() {
  ls "${OLDHOME}"/"${1:-}"
}

_lsbkh_autocomplete() {
  local cur
  cur=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=( $(compgen -f ${OLDHOME}/$cur | cut -d"/" -f5 ) )
}
complete -o filenames -F _lsbkh_autocomplete lsbkh