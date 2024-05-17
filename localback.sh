function restore() (
  global=0
  LOC=$1
  merge=1
  clobber=0
  glob=0
  help () {
    echo "A simple wrapper function to restore from a backup dir on a"
    echo "fresh install."
    echo " " 
    echo "To work properly the following vars must be set to paths"
    echo "containing data to be restored:"
    echo " - OLDHOME, user files organized as they should be pulled into"
    echo "            the new system."
    echo " - OLDSYS, files and software from outside the users homedir,"
    echo "           activated by using the -n (nonpersonalized) flag."
    echo " "
    echo "-n is for non-personalized software from a local source"
    echo "   but still restored to \$HOME."
    echo "-g globs the restore target, will try to restore anything"
    echo "   that exists in the backup like '*term*'.  We glob so you"
    echo "   don't have to."sent
    echo "-o will overwrite any existing files / dirs."
    echo "   Default is to merge"
    echo "-c when used with -o, will clobber newer files in the"
    echo "   destination directory. Default is to only update."
  }

    do_restore() {
    LOC="${1:-}"
    if [ $global -eq 1 ]; then 
      BK="${OLDSYS}"
    else
      BK="${OLDHOME}"
    fi
    if ! [ -e "$BK/${loc}" ]; then
      >&2 printf "could not find original at $BK/$loc"
      return 1
    fi
    # mounted=$(mountpoint $HOME/$TARGET);
    # if [ $? -ne 0 ]; then
    #   $LH/mounter-t.sh
    # fi
    if [ $merge -ne 0 ]; then
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
        new="$BK/$LOC"
        old="$HOME/$LOC"
        confirm_yes "restoring $new to $old... ok?"
        mkdir -p $HOME/.bak
        if [ -d "$old" ]; then 
          echo "Backing up existing $old to .bak"
          if ! cp -vr "$old" "$HOME/.bak"; then
            return $?
          fi
        fi
        cp -vr "$new" "$HOME/"
        return $?
      else
        se "Didn't find a backup directory at $BK. exiting."
        return 1
      fi
    elif [ $clobber -eq 1 ]; then
      confirm_yes "merging $new to $old, clobbering newer files... ok?"
      rsync -rltv "new" "$home"
      return $?
    else
      confirm_yes "merging $new to $old if it exists... ok?"
      rsync -rlutv "$new" "$home"
      return $?
    fi
  }
  
  args=$(getopt -o ngoch --long nonpersonalized,glob,overwrite,clobber,help -- "$@")
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
      -g|--glob)
        glob=1
        shift 
        ;;
      -o|--overwrite)
        merge=0
        shift
        ;;
      -c|--clobber)
        clobber=1
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
  for loc in "${POSITIONAL_ARGS[@]}"; do
    if ! do_restore "${loc}"; then 
        ((failures++))
    fi
  done
  return ${failures}
)