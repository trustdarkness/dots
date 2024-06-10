#!/bin/bash
# for portability we need the above, for the mac os, we need the below
if [ -f "/usr/local/bin/bash" ] && [[ $(uname) == "Darwin" ]] && [[ ${BASH_VERSINFO[0]} -lt 5 ]]; then 
  /usr/local/bin/bash
fi

if [[ "${FUNCNAME[0]}" == "i" ]]; then 
  sudo echo "Ready."
else
  echo "${FUNCNAME}"
fi
if [[ $(uname) == "Linux" ]]; then
  distro="$(lsb_release -d 2>&1|egrep Desc|awk -F':' '{print$2}'|xargs)"
elif [[ $(uname) == "Darwin" ]]; then
  source $D/macutil.sh
fi


distro="$(lsb_release -d 2>&1|grep Desc|awk -F':' '{print$2}'|xargs)"

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
    sudo aptitude install $@
  }
  function sau() {
    aptitude update 
  }
  function sauu() {
    sudo aptitude update && sudo aptitude upgrade
  }
  function sas() {
    sudo aptitude search $@
  }
  function sar() {
    aptitude remove #@
  }
  function sap() {
    aptitude purge $@
  }
  function saar() {
    apt-add-repository $@
  }
  function sAAR() {
    apt auto-remove $@
  }
  function vasl() {
    vim /etc/apt/sources.list 
  }
  function asl() {
    echo /etc/apt/sources.list
  }
  function vasld() {
     vim /etc/apt/sources.list.d
  }
  function saig() {
    pattern=$1
    sudo apt install *$pattern*
  }
  export -f saig
  function sarg() {
    pattern=$1
    sudo apt remove *$pattern*
  }

  function sapg {
    for term in $@; do
      pattern="*$term*"
      sudo apt purge $pattern
    done
  }
  export -f sapg
  function sasi {
    pattern=$1
    sudo aptitude search $pattern|grep ^i
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
    sudo sed -i.bak 's@#deb\ https://deb.debian.org/debian/\ sid@deb\ https://deb.debian.org/debian/\ sid@g' /etc/apt/sources.list
    sau
    sas $pattern
    sudo sed -i.bak 's@deb\ https://deb.debian.org/debian/\ sid@#deb\ https://deb.debian.org/debian/\ sid@g' /etc/apt/sources.list
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
  export -f sai-oldstable
  function sai-unstable {
    pattern=$1
    sudo sed -i.bak 's@#deb\ https://deb.debian.org/debian/\ sid@deb\ https://deb.debian.org/debian/\ sid@g' /etc/apt/sources.list
    sau
    sai $pattern
    sudo sed -i.bak 's@deb\ https://deb.debian.org/debian/\ sid@#deb\ https://deb.debian.org/debian/\ sid@g' /etc/apt/sources.list
    sau
  }
fi

if string_contains "Darwin" $distro; then 
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
fi

function yabridge_bootstrap() {
  if [ -d $HOME/Downloads/yabridge ]; then 
    cp -r $HOME/Downloads/yabridge $HOME/.local/share/
  elif [ -d $HOME/bin/yabridge ]; then 
    cp -r $HOME/bin/yabridge $HOME/.local/share/
  else
    >&2 printf "Can't find yabridge updates in"
    >&2 printf "$HOME/Downloads or $HOME/bin"
  fi
}