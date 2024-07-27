#!/usr/bin/env bash

if [[ $(uname) == "Linux" ]]; then
  distro="$(lsb_release -d 2>&1|egrep Desc|awk -F':' '{print$2}'|xargs)"
elif [[ $(uname) == "Darwin" ]]; then
  source $D/macutil.sh
  function sai() {
    brew install $@
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

fi

if string_contains "arch" "$distro"; then
  function sai() {
    sudo pacman -Sy $@
  }
  function sau() {
    sudo pacman -Syu 
  }
  function sauu() {
    pacman -Syu $@
  }
  function sas() {
    yay -Ss $@
  }
  function sar() {
    sudo pacman -Rscn $@
  }
fi

if string_contains "(fedora|nobara)" "$distro"; then
  function sai() {
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
  alias di="sudo dpkg -i"
  function sai() {
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
  export -f saig
  function sarg() {
    pattern=$1
    sudo apt remove $(printf '*%s*' "$pattern")
  }

  function sapg {
    for term in $@; do
      sudo apt purge $(printf '*%s*' "$term")
    done
  }
  export -f sapg
  function sasi {
    pattern=$1
    sudo aptitude search $pattern|grep ^i
  }
  function sasg() {
    aptpattern="${1:-}"
    egreppattern="${2:-}"
    sudo aptitude search "$aptpattern" | egrep "$greppattern"
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
