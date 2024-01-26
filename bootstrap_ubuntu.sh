#!/usr/bin/env bash

which apt >/dev/null 2>&1 && {
  grep '16.04' /etc/lsb-release >/dev/null 2>&1 && {
    packages=(
      ## to get easy_install
      software-properties-common 
      python-software-properties

      python-setuptools 
      python-dev 
      gcc

      ## to get this repo
      git

      ## nice to have
      vim
      htop

      ## for ansible
      sshpass
    )
  }
  
  grep '18.04' /etc/lsb-release >/dev/null 2>&1 && {
    packages=(
      ## python-pip and deps
      software-properties-common 

      python-setuptools 
      python-pip
      python-dev 
      gcc

      ## to get this repo
      git

      ## nice to have
      vim
      htop

      ## for ansible
      sshpass
    )
  }
}

pip_packages=(
  pipenv
)

sudo apt-get -y install "${packages[@]}"

grep '16.04' /etc/lsb-release >/dev/null 2>&1 && {
  sudo easy_install pip
}

sudo pip install "${pip_packages[@]}"
