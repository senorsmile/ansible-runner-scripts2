#!/usr/bin/env bash

set -euo pipefail # bash strict mode


INOPTS=("$@")

if [[ ${#INOPTS[@]} -eq 0 ]]; then
  INOPTS=("")
fi

sitefile="${SITEFILE:-site.yml}"
inventorydir="${INVENTORYDIR:-./inventory/}"
vaultfile="${VAULTFILE:-$HOME/.ssh/creds/ansible_vault.txt}"
ansiblever="${ANSIBLEVER:-2.7}"
ansiblemode="${ANSIBLEMODE:-PLAYBOOK}" # [PLAYBOOK, ADHOC]


if [[ "${INVENTORYVER+DEFINED}" ]]; then
  inventoryver="${INVENTORYVER}"
fi
if [[ "${INVENTORYREPO+DEFINED}" ]]; then
  inventoryrepo="${INVENTORYREPO}"
fi


save_dir() {
  ## save current directory
  pushd . &>/dev/null
}

return_dir() {
  ## return to original directory
  popd &>/dev/null
}

symlink_src_dir() {
  # get the actual dir
  # when this is run as a symlink

  SOURCE="${BASH_SOURCE[0]}"
  while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  done
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  echo "${DIR}"
}

inventory_checkout() {
  # do nothing if inventoryrepo is not defined
  if [[ "${inventoryrepo+DEFINED}" ]]; then

    inventoryrepo_name=$(
      echo "${inventoryrepo}" | 
      perl -lane 'print $1 if /.*\/([\w-]+)\.git/'
    )

    if [[ ! -d "${inventorydir}" ]]; then
      mkdir "${inventorydir}"
    fi

    if [[ ! -d "${inventorydir}/${inventoryrepo_name}/" ]]; then
      save_dir
      cd "${inventorydir}"
      git clone "${inventoryrepo}"
      return_dir
    fi
    save_dir
    cd "${inventorydir}/${inventoryrepo_name}"
    git checkout master
    git pull --rebase
    if [[ ${inventoryver} != 'master' ]]; then
      git checkout "${inventoryver}"
      git pull --rebase
    fi
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

  # get real dir (in case symlink)
  local realdir=$(symlink_src_dir)

  # create symlink for Pipfile
  if [[ ! "./Pipfile" -ef "${realdir}/ansible_${ansiblever}/Pipfile" ]]; then
    #rm "./Pipfile"
    ln -s "${realdir}/ansible_${ansiblever}/Pipfile"
  fi

  # create symlink for Pipfile.lock (and pipenv install if not there)
  if [[ ! "./Pipfile.lock" -ef "${realdir}/ansible_${ansiblever}/Pipfile.lock" ]]; then

    if [[ ! -s "${realdir}/ansible_${ansiblever}/Pipfile.lock" ]]; then
      echo "Pipfile.lock does not exist.  Installing..."
      save_dir
      cd "${realdir}/ansible_${ansiblever}"
      pipenv install
      return_dir
    fi

    #rm "./Pipfile.lock"
    ln -s "${realdir}/ansible_${ansiblever}/Pipfile.lock"
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
  #export ANSIBLE_STDOUT_CALLBACK='debug'
  export ANSIBLE_STDOUT_CALLBACK='yaml'

  echo "******** ----------------"
  echo "******** Ansible version "
  echo "******** ----------------"
  pipenv run ansible --version
  echo

  echo "******** ------------"
  echo "******** Ansible run "
  echo "******** ------------"

  # if using repo for central inventory,
  # redefined inventorydir
  if [[ "${inventoryrepo+DEFINED}" ]]; then
    inventorydir="${inventorydir}/${inventoryrepo_name}"
  fi

  if [[ $ansiblemode == 'PLAYBOOK' ]]; then
      opts=(
        ansible-playbook
        -i "${inventorydir}"
        --diff
        ${VAULTOPTS}
        "${sitefile}"
        #--become
        ${INOPTS[@]}
      )
      pipenv run ${opts[@]}
  elif [[ $ansiblemode == 'ADHOC' ]]; then
      opts=(
        ansible
        -i "${inventorydir}"
        --diff
        ${VAULTOPTS}
        #--become
        ${INOPTS[@]}
      )
      pipenv run  ${opts[@]}
  else
      echo "Invalived ansiblemode=${ansiblemode}"
      echo "Valid options:"
      echo "  PLAYBOOK"
      echo "  ADHOC"
      exit 1
  fi
}

main() {
  run_ansible_playbook
}

time main
