#!/usr/bin/env bash

set -euo pipefail # bash strict mode


INOPTS=("$@")

if [[ ${#INOPTS[@]} -eq 0 ]]; then
  INOPTS=("")
fi

site="${SITEFILE:-site.yml}"
inventorydir="${INVENTORYDIR:-./inventory/}"
#inventoryver="${INVENTORYVER:-master}"
#inventoryrepo="${INVENTORYREPO:-/change/me}"
vaultfile="${VAULTFILE:-$HOME/.ssh/creds/ansible_vault_senorsmile_personal.txt}"
ansiblever="${ANSIBLEVER:-2.7}"

save_dir() {
  ## save current directory
  pushd . &>/dev/null
}

return_dir() {
  ## return to original directory
  popd &>/dev/null
}

inventory_checkout() {
  # do nothing if inventoryrepo is not defined
  if [[ "${inventoryrepo+DEFINED}" ]]; then

    if [[ ! -d "${inventorydir}" ]]; then
      git clone "${inventoryrepo}"
    fi

    save_dir
    cd "${inventorydir}"
    git checkout master
    git pull --rebase
    git checkout "${inventoryver}"
    git pull --rebase
    git submodule update --init --recursive
    return_dir

  fi
}

check_vaultfile() {
  if [[ -f "${vaultfile}" ]]; then
    echo "TRUE"
  else
    echo "FALSE"
  fi
}

check_installed() {
  if which "$1" &> /dev/null; then
    : # all good
  else
    echo "$1 is not installed.  Exiting..."
    exit 1
  fi 
}

pipenv_init() {
  check_installed pipenv

  # err out if either file exists but is NOT a symbolic link
  if [[ -f "./Pipfile" && ! -h "./Pipfile" ]] || [[ -f "./Pipfile.lock" && ! -h "./Pipfile.lock" ]]; then
    echo "Pipfile and Pipfile.lock should be a symbolic link, but is not."
    echo "Backup and remove that file so this script can manage it."
    exit 1
  fi

  # create symlink for Pipfile
  if [[ ! "./Pipfile" -ef "ansible_${ansiblever}/Pipfile" ]]; then
    rm "./Pipfile"
    ln -s "ansible_${ansiblever}/Pipfile"
  fi

  # create symlink for Pipfile.lock (and pipenv install if not there)
  if [[ ! "./Pipfile.lock" -ef "ansible_${ansiblever}/Pipfile.lock" ]]; then

    if [[ ! -s "./ansible_${ansiblever}/Pipfile.lock" ]]; then
      echo "Pipfile.lock does not exist.  Installing..."
      cd "ansible_${ansiblever}"
      pipenv install
      cd ..
    fi

    rm "./Pipfile.lock"
    ln -s "ansible_${ansiblever}/Pipfile.lock"
  fi


  pipenv sync
}

run_ansible_playbook() {
  echo "******** -------------------"
  echo "******** Inventory Checkout "
  echo "******** -------------------"
  inventory_checkout
  echo

  echo "******** ------------"
  echo "******** Init pipenv "
  echo "******** ------------"
  pipenv_init
  echo
  
  if [[ $(check_vaultfile) == "TRUE" ]]; then
    VAULTOPTS="--vault-password-file=${vaultfile}"
  else
    VAULTOPTS=""
  fi

  export ANSIBLE_CALLBACK_WHITELIST='timer,profile_tasks'

  echo "******** ----------------"
  echo "******** Ansible version "
  echo "******** ----------------"
  pipenv run ansible --version
  echo

  echo "******** ------------"
  echo "******** Ansible run "
  echo "******** ------------"
  opts=(
    ansible-playbook      
    -i "${inventorydir}"
    --diff              
    ${VAULTOPTS}        
    "${site}"           
    #--become            
    ${INOPTS[@]}
  )
  pipenv run ${opts[@]}
}

main() {
  run_ansible_playbook
}

time main
