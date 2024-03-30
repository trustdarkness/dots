if [[ caller == "i" ]]; then 
  sudo echo "Ready."
fi

vasl

alias distro="lsb_release -a"

if stringContains "arch" "$distro"; then
  alias sai="sudo pacman -Sy"
  alias sau="sudo pacman -Syu"
  alias sauu="sudo pacman -Syu"
  alias sas="yay -Ss"
  alias sar="sudo pacman -Rscn"
fi

if stringContains "(fedora|nobara)" "$distro"; then
  alias sai="sudo dnf install -y"
  alias sau="sudo dnf upgrade -y"
  alias sauu="sudo dnf upgrade -y"
  alias sas='sudo dnf search'
  alias sar="sudo dnf remove -y"
fi

if stringContains "(debian|ubuntu)" "$distro"; then
  alias sai="sudo aptitude install"
  alias sau="sudo aptitude update"
  alias sauu="sudo aptitude update && sudo aptitude upgrade"
  alias sas="sudo aptitude search"
  alias sar="sudo aptitude remove"
  alias sap='sudo aptitude purge'
  alias saar="sudo apt-add-repository"
  alias sAAR="sudo apt auto-remove"
  alias vasl="sudo vim /etc/apt/sources.list"
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

function yainst() {
  if [ -d $HOME/Downloads/yabridge ]; then 
    cp -r $HOME/Downloads/yabridge $HOME/.local/share/
  elif [ -d $HOME/bin/yabridge ]; then 
    cp -r $HOME/bin/yabridge $HOME/.local/share/
  else
    >&2 printf "Can't find yabridge updates in"
    >&2 printf "$HOME/Downloads or $HOME/bin"
  fi
}