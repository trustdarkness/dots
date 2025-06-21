#!/usr/bin/env bash

default_installer=undefined

# PS1=$(printf "$PS1TEMPLATE" "📦")

if [[ $(uname) == "Linux" ]]; then
  distro="$(lsb_release -d 2>&1|grep -E Desc|awk -F':' '{print$2}'|xargs)"
elif [[ $(uname) == "Darwin" ]]; then
  default_installer=brew

  source $D/macutil.sh
  function sai() {
    brew install $@
  }
  # brew already doesn't ask for confirmation, but for
  # cross platform consistency
  function sayi() {
    sai $@
  }
  function sas() {
    brew search $@
  }
  function sau() {
    brew update
  }
  function sauu() {
    brew update && brew upgrade
  }
  function salu() {
    sudo softwareupdate --list
  }
  function salu_macos() {
    if mist=$(type -p mist); then
      $mist list installer
    else
      sudo softwareupdate --list-full-installers
    fi
  }
  function sar() {
    brew uninstall $@
  }
  # depends util.sh
  #  - wget-download-size
  #  - is_int
  #  - spinner-{start,stop}
  function brew_pkg_size() {
    verbose=false
    if [ -z "${INF}" ]; then
      # assume deps for colors not in env and attempt to proceed without
      INF= ; STAT= ; RST= ;
    fi
    if [[ "${1:-}" =~ \-v ]]; then verbose=true; shift; fi
    pkg="${1:-}"
    if [ -t 1 ] && ! $verbose; then spinner-start; fi
    cat="$(brew cat "$pkg")"
    if tru $verbose; then >&2 echo "${INF}brew cat: ${STAT}$cat${RST}"; fi
    urlline="$(grep -m1 url <<< "$cat")"
    if tru $verbose; then >&2 echo "${INF}extracted stable: ${STAT}$urlline${RST}"; fi
    url="$(echo "$urlline" |awk '{print$2}')"
    if tru $verbose; then >&2 echo "${INF}extracted url: ${STAT}$url${RST}"; fi
    noquotes=$(stripquotes "$url")
    if tru $verbose; then >&2 echo "${INF}noquotes url: ${STAT}$url${RST}"; fi
    length="$(wget-download-size $noquotes)"
    if tru $verbose; then >&2 echo "${INF}wget output: ${STAT}$length${RST}"; fi
    if [ -t 1 ] && ! $verbose; then spinner-stop; fi
    if [ -n "$length" ] && is_int "$length"; then
      echo "$length"
      return 0
    fi
    return 1
  }

  function pkg_footprint() {
    if [[ "${1:-}" =~ \-(b|\-breakdown) ]]; then
      shift
      pkg="${1:-}"
      printf "%s " "$pkg"
      size="$(brew_pkg_size "${1:-}")"
      bytes_converter "$size" MB
      deps=()
      sizes=()
      while IFS=$'\n' read -r line; do
        deps+=("$line")
      done < <(brew deps "${1:-}")
      total="${#deps[@]}"
      if [ -t 1 ]; then progress-init; fi
      ctr=0
      for P in "${deps[@]}"; do
        if [ -t 1 ]; then progress "$ctr" "$total" "Adding dependency $P"; fi
        sizes+=("$(brew_pkg_size "$P")")
        ((ctr++))
      done
      echo "dependencies: "
      ctr=0
      for P in "${deps[@]}"; do
        printf "   %s: " "$P"
        bytes_converter "${sizes[$ctr]}" MB
      done
    else
      pkg="${1:-}"
      # https://github.com/Homebrew/brew/issues/18373
      accumulator=$(brew_pkg_size "${1:-}")
      dep_count=0
      if [ -t 1 ]; then progress-init; fi
      for P in $(brew deps "${1:-}"); do
        if [ -t 1 ]; then progress "$dep_count" "$total" "calculating dependency $P"; fi
        ((accumulator+=$(brew_pkg_size "$P")))
        ((dep_count++))
      done
      spinner-stop
      printf "${1:-} with $dep_count dependencies: "
      bytes_converter "$accumulator" MB
    fi
  }

fi

if string_contains "(arch|Manjaro|endeavour)" "$distro"; then
  default_installer=pacman
  function sai() {
    sudo pacman -Sy $@
  }
  function sayi() {
    sudo pacman -Sy --noconfirm $@
  }
  function yai() {
    yay -Sy $@
  }
  function yayi() {
    local localbin="$HOME/.local/bin/"
    local yp="$localbin/ypacman"
    if ! [ -x "$HOME/.local/bin/ypacman" ]; then
      if ! [ -f "$yp" ]; then
        se "no ypacman in $HOME/.local/bin"
        if confirm_yes "create this?"; then
          printf '#!%s %s\n%s --noconfirm $@\n' "$(type -p env)" "bash" "$(type -p pacman)" > "$yp"
          chmod +x "$yp"
        fi
      fi
    fi
    yay --pacman "$yp" -Sy $@
  }
  function sau() {
    sudo pacman -Syu
  }
  function sauu() {
    sudo pacman -Syu $@
  }
  function sas() {
    sudo pacman -Ss $@
  }
  function sasn() {
    sudo pacman -Ss "^${1:-}"
   }
  function sasy() {
    yay -Ss $@
  }
  function sar() {
    sudo pacman -Rscn $@
  }
  function safs() {
    sudo pacman -F $@
  }
  function salo() {
    sudo pacman -Qdt $@
  }
  function sauud() {
    yay -Syu --devel $@
  }
  function yRO() {
    yay -R "$(yay -Qtd|awk '{print$1}'|xargs)"
  }
  function installed_groups_list() {
    # https://bbs.archlinux.org/viewtopic.php?id=251788
    pacman -Qg | cut -d' ' -f1 | sort -u | {
      while read group; do
        grep -q "Running 'pacman.*-S[yu]* $group" /var/log/pacman.log &&
          echo $group
      done
    }
  }
fi


if string_contains "(fedora|nobara)" "$distro"; then
  default_installer=dnf
  function sai() {
    sudo dnf install $@
  }
  function sayi() {
    sudo dnf install -y $@
  }
  function sau() {
    sudo dnf upgrade -y
  }
  function sauu() {
    sudo dnf upgrade -y $@
  }
  function sas() {
    sudo dnf search $@
  }
  function sar() {
    sudo dnf remove -y $@
  }
fi

if string_contains "(Debian|Ubuntu)" "$distro"; then
  default_installer=aptitude
  alias di="sudo dpkg -i"
  function sai() {
    sudo aptitude install $@
  }
  function sayi() {
    sudo aptitude install -y $@
  }
  # aptitude sometimes wants to force uninstall no longer required depends
  function sapti() {
    sudo apt install -y $@
  }
  function sau() {
    sudo aptitude update
  }
  function sauu() {
    sudo aptitude update && sudo aptitude upgrade
  }
  function sadu() {
    sudo aptitude dist-upgrade
  }
  function sas() {
    sudo aptitude search $@
  }
  function sar() {
    sudo aptitude remove $@
  }
  # sometimes aptitude trying to be "smart" means it doesn't do what we tell it
  function saptr() {
    sudo apt remove $@
  }
  function sap() {
    sudo aptitude purge $@
  }
  function saar() {
    sudo apt-add-repository $@
  }
  function sAAR() {
    sudo apt auto-remove $@
  }
  function sacfs() {
    sudo apt-cache search $@
  }
  function safs() {
    if ! type -p apt-file 2>&1 > /dev/null; then
      sayi apt-file
      sudo apt-file update
    fi
    sudo apt-file find
  }
  function vasl() {
    sudo vim /etc/apt/sources.list
  }
  function asl() {
    echo /etc/apt/sources.list
  }
  function vasld() {
     sudo vim /etc/apt/sources.list.d
  }
  function saig() {
    pattern=$1
    sudo apt install $(printf '*%s*' "$pattern")
  }

  function sarg() {
    pattern=$1
    sudo apt remove $(printf '*%s*' "$pattern")
  }

  function sapg {
    for term in $@; do
      sudo apt purge $(printf '*%s*' "$term")
    done
  }

 function sfr() {
   for pkg in $@; do
     sudo dpkg --remove --force-remove-reinstreq $pkg
   done
 }

  function sasi {
    pattern=$1
    sudo aptitude search $pattern|grep ^i
  }
  function sasg() {
    aptpattern="${1:-}"
    egreppattern="${2:-}"
    sudo aptitude search "$aptpattern" | grep -E "$greppattern"
  }
  function sas-oldskool {
    pattern=$1
    sudo sed -i.bak 's@#deb\ http://archive@deb\ http://archive@g' /etc/apt/sources.list
    sau
    sas $pattern
    sudo sed -i.bak 's@deb\ http://archive@#deb\ http://archive@g'  /etc/apt sources.list
    sau
  }

  function sas-oldstable {
    pattern=$1
    sudo sed -i.bak 's@#deb\ https://deb.debian.org/debian/\ oldstable@deb\ https://deb.debian.org/debian/\ oldstable@g' /etc/apt/sources.list
    sau
    sas $pattern
    sudo sed -i.bak 's@deb\ https://deb.debian.org/debian/\ oldstable@#deb\ https://deb.debian.org/debian/\ oldstable@g' /etc/apt/sources.list
    sau
  }

  function sas-unstable {
    pattern=$1
    # a working sid line must be present as a comment in /etc/apt/sources.list
    # we use @ as seds field separator and just remove, then replace the # comment
    sudo sed -E -i.bak 's@#deb(.*)sid@deb\1sid@g' /etc/apt/sources.list
    sau
    sas $pattern
    sudo sed -E -i.bak 's@deb(.*)sid@#deb\1sid@g' /etc/apt/sources.list
    sau
  }
  alias sas-sid="sas-unstable"

  function sas-testing {
    pattern=$1
    sudo sed -E -i.bak 's@#deb(.*)testing@deb\1testing@g' /etc/apt/sources.list
    sau
    sas $pattern
    sudo sed -E -i.bak 's@deb(.*)testing@#deb\1testing@g' /etc/apt/sources.list
    sau
  }


  function sai-oldskool {
    pattern=$1
    sudo sed -i.bak '/archive/ s@#deb\ http://archive@deb\ http://archive@g' /etc/apt/sources.list
    sau
    sai $pattern
    sudo sed -i.bak '/archive/ s@deb\ http://archive@#deb\ http://archive@g'  /etc/apt sources.list
    sau
  }

  function sai-oldstable {
    pattern=$1
    sudo sed -i.bak 's@#deb\ https://deb.debian.org/debian/\ oldstable@deb\ https://deb.debian.org/debian/\ oldstable@g' /etc/apt/sources.list
    sau
    sai $pattern
    sudo sed -i.bak 's@deb\ https://deb.debian.org/debian/\ oldstable@#deb\ https://deb.debian.org/debian/\ oldstable@g' /etc/apt/sources.list
    sau
  }

  function sai-unstable {
    pattern=$1
    sudo sed -E -i.bak 's@#deb(.*)sid@deb\1sid@g' /etc/apt/sources.list
    sau
    sai $pattern
    sudo sed -E -i.bak 's@deb(.*)sid@#deb\1sid@g' /etc/apt/sources.list
    sau
  }
  alias sai-sid="sai-unstable"

  function sai-testing {
    pattern=$1
    sudo sed -E -i.bak 's@#deb(.*)testing@deb\1testing@g' /etc/apt/sources.list
    sau
    sai $pattern
    sudo sed -E -i.bak 's@deb(.*)testing@#deb\1testing@g' /etc/apt/sources.list
    sau
  }



fi
