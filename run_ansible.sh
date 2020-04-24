#!/usr/bin/env bash

set -euo pipefail # bash strict mode

INOPTS=("$@")
EXTRAOPTS=("")

if [[ ${#INOPTS[@]} -eq 0 ]]; then
  INOPTS=("")
fi

sitefile="${SITEFILE:-site.yml}"
ansiblever="${ANSIBLEVER:-2.9}"
ansiblemode="${ANSIBLEMODE:-PLAYBOOK}" # [PLAYBOOK, ADHOC, INVENTORY]
extrainit="${EXTRAINIT:-_init_vars.sh}"
inventorydisable="${INVENTORYDISABLE:-false}"
# NB: you can define EXTRAOPTS in order to e.g. load multiple inventories


# TODO: remove this?
#if [[ -e "$HOME/.bashrc" ]]; then
#    source "$HOME/.bashrc"
#fi


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
  # do nothing if inventoryrepo is not defined or it is disabled
  if [[ "${INVENTORYREPO+DEFINED}" && $inventorydisable == "false" ]]; then
    inventoryrepo="${INVENTORYREPO}"
    inventoryver="${INVENTORYVER:-master}"

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

check_installed_no_exit() {
  if which "$1" &> /dev/null; then
    echo "OK"
  else
    echo "MISSING"
  fi
}

pyenv_init() {
  if [[ -d $HOME/.pyenv ]]; then
    # try to load pyenv before checking (in case bash_profile,bashrc etc. not working)
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    set +u
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
    set -u

  else
    case "$(uname -s)" in
      Darwin)
        curl https://pyenv.run | bash
        ;;

      Linux)
        if [[ "$(which apt)" != "" ]]; then
          sudo apt-get update

          echo "---------------------------------------------"
          echo '------ install pyenv prereqs'
          echo "---------------------------------------------"
          sudo DEBIAN_FRONTEND=noninteractive apt-get -y install make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev 

          echo "---------------------------------------------"
          echo '------ install pyenv as user'
          echo "---------------------------------------------"
          curl https://pyenv.run | bash

          my_shell=$(echo "$SHELL")
          if [[ "$my_shell" =~  "bash" ]]; then
            echo "---------------------------------------------"
            echo '------ enable pyenv from bashrc'
            echo "---------------------------------------------"
            echo -en 'export PATH="/home/vagrant/.pyenv/bin:$PATH"\neval "$(pyenv init -)"\neval "$(pyenv virtualenv-init -)"' >> $HOME/.bashrc
          else
            echo "---------------------------------------------"
            echo '------ enable pyenv from bashrc'
            echo "---------------------------------------------"
            echo "ERROR: Your shell: ${SHELL} is not yet accounted for."  
            echo "       Please check to see that pyenv is initialized properly in your shell's init files."
            echo "       See more information here: https://github.com/pyenv/pyenv#basic-github-checkout"
          fi
        else
          echo "WARNING: untested linux distro.  May need modifications to work."

          echo "---------------------------------------------"
          echo '------ install pyenv as user'
          echo "---------------------------------------------"
          curl https://pyenv.run | bash
        fi

        ;;
    esac

    # load  pyenv after installation
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    set +u
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
    set -u


  fi

  # TODO: this does not work
  #if [[ -f .python-version ]]; then 
  #  pyenv install
  #fi
}

pipenv_init() {
  check_installed python3
  pipenv_installed=$(check_installed_no_exit pipenv)
  if [[ $pipenv_installed == 'MISSING' ]]; then
    echo "---------------------------------------------"
    echo "------ Pipenv not found.  Installing locally"
    echo "---------------------------------------------"
    if [[ -e /tmp/get-pipenv.py ]]; then
      echo "---------------------------------------------"
      echo "------ Removing old get-pipenv.py version"
      echo "---------------------------------------------"
      rm /tmp/get-pipenv.py
    fi

    case "$(uname -s)" in
      Darwin)
        echo 'Mac OS X'
        brew install pipenv
        ;;

      Linux)
        echo 'Linux'
        if [[ "$(which apt)" != "" ]]; then
          export DEBIAN_FRONTEND=noninteractive
          export UCF_FORCE_CONFOLD=1
          echo "---------------------------------------------"
          echo "--- update apt"
          echo "---------------------------------------------"
          sudo apt-get update

          echo "---------------------------------------------"
          echo "--- install python3-pip"
          echo "---------------------------------------------"
          echo 'libssl1.1 libraries/restart-without-asking boolean true' | sudo debconf-set-selections
          sudo apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -qq -y install python3-pip

          echo "---------------------------------------------"
          echo "--- pip install pipenv --user"
          echo "---------------------------------------------"

          pip3 install pipenv --user || exit 1

          # load --user install python package path manually
          # since some non-interactive envs will NOT load bashrc
          [[ -d $HOME/.local/bin ]] && {
            PATH="$HOME/.local/bin:$PATH"
            echo "Path is $PATH"
          }

          echo "---------------------------------------------"
          echo '------ enable pip --user installations to be accesible'
          echo "---------------------------------------------"
          if [[ -e "$HOME/.bashrc" ]]; then

              do_lines_exist=$(perl -e '
                  BEGIN { $found=0; }

                  my $contents = do {local $/; <>};

                  while ($contents =~ m|\[\[ -d \$HOME/.local/bin \]\] && \{\n  PATH="\$HOME/.local/bin:\$PATH"\n\}|sg) {

                      $found=1;
                  }

                  END {
                      if ($found) {
                          print "FOUND\n";
                      }
                  }
              ' "$HOME/.bashrc")

              if [[ ! $do_lines_exist == "FOUND" ]]; then
                  echo -en '\n[[ -d $HOME/.local/bin ]] && {\n  PATH="$HOME/.local/bin:$PATH"\n}' >> $HOME/.bashrc
              fi

              #source "$HOME/.bashrc" # TODO: remove this?
          else
              echo ".bashrc not found.  Pipenv (and other user installed pip apps) may not work."
          fi



        elif [[ "$(which dnf)" != "" ]]; then
          dnf install -y pipenv

        else
          echo 'Failure.  pipenv and/or pip3 not installed but this script cannot detect how to install.'
          exit 1

        fi
        ;;

      *)
        echo 'Other OS'
        echo 'Could not detect OS, failing out..'
        exit 1
        ;;
    esac
  fi

  if [[ pipfile_symlink == 'ENABLED' ]]; then
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
  else # not symlinking provided Pipefile*
      if [[ ! -f "./Pipfile" ]]; then
        echo "Auto Symlinking to the provided Pipfile's has been disabled."
        echo "However, no Pipfile is present in the current directory."
        echo "Exiting."
        exit 1
      fi
      if [[ ! -f "./Pipfile.lock" ]]; then
        pipenv install
      fi
  fi

  #pipenv --python $(which python3)
  pipenv sync
}

load_extra_init() {
  if [[ -f "${extrainit}" ]]; then
    source "${extrainit}"
  fi
}

run_ansible_playbook() {
  echo "******** --------------------------"
  echo "********  Load extra initialization"
  echo "******** --------------------------"
  load_extra_init
  echo

  inventorydir="${INVENTORYDIR:-./inventory/}"
  pipfile_symlink="${PIPFILE_SYMLINK:-ENABLED}"

  echo "******** -------------------"
  echo "******** Inventory Checkout "
  echo "******** -------------------"
  inventory_checkout
  echo

  echo "******** ------------"
  echo "******** Init pyenv "
  echo "******** ------------"
  pyenv_init
  echo

  echo "******** ------------"
  echo "******** Init pipenv "
  echo "******** ------------"
  pipenv_init
  echo

  echo "******** ----------------"
  echo "******** Init vault file "
  echo "******** ----------------"
  vaultfile="${VAULTFILE:-$HOME/.ssh/creds/ansible_vault.txt}"
  if [[ $(check_vaultfile) == "TRUE" ]]; then
    VAULTOPTS="--vault-password-file=${vaultfile}"
  else
    VAULTOPTS=""
  fi
  echo

  export ANSIBLE_CALLBACK_WHITELIST='timer,profile_tasks'
  #export ANSIBLE_STDOUT_CALLBACK='debug'
  export ANSIBLE_STDOUT_CALLBACK='yaml'

  echo "******** ----------------"
  echo "******** Ansible version "
  echo "******** ----------------"
  pipenv run ansible --version
  echo

  echo "******** ---------------"
  echo "******** Inventory Load "
  echo "******** ---------------"
  # if using repo for central inventory,
  if [[ "${inventoryrepo+DEFINED}" && $inventorydisable == "false" ]]; then
    # redefine inventorydir
    inventorydir="${inventorydir}/${inventoryrepo_name}"

    INVOUTPUT=$(pipenv run ansible localhost -i "${inventorydir}" --list-hosts 2>&1)
    if [[ "${INVOUTPUT}" == *"No inventory was parsed"* ]]; then
      echo "*** Inventory Load NOT Successful"
    else
      echo "*** Inventory Load NOT Successful"
    fi
  fi
  #pipenv run ansible localhost -i "${inventorydir}" --list-hosts >/dev/null && {
  #  echo "*** Inventory Load Successful"
  #}
  echo

  echo "******** ------------"
  echo "******** Ansible run "
  echo "******** ------------"

  if [[ $ansiblemode == 'PLAYBOOK' ]]; then
      opts=(
        ansible-playbook
        -i "${inventorydir}"
        --diff
        ${VAULTOPTS}
        "${sitefile}"
        ${EXTRAOPTS[@]}
        ${INOPTS[@]}
      )
      set -x
      pipenv run ${opts[@]}
  elif [[ $ansiblemode == 'ADHOC' ]]; then
      opts=(
        ansible
        -i "${inventorydir}"
        --diff
        ${VAULTOPTS}
        ${EXTRAOPTS[@]}
        ${INOPTS[@]}
      )
      set -x
      pipenv run  ${opts[@]}
  elif [[ $ansiblemode == 'INVENTORY' ]]; then
      opts=(
        ansible-inventory
        -i "${inventorydir}"
        ${VAULTOPTS}
        ${EXTRAOPTS[@]}
        ${INOPTS[@]}
      )
      set -x
      pipenv run ${opts[@]}
  else
      echo "Invalid ansiblemode=${ansiblemode}"
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
