# -*- mode: ruby -*-
# vi: set ft=ruby :

nodes = [
  { :hostname => 'vagrant_ansible_runner',  
    :ip => '192.168.110.101', 
    :box => 'ubuntu/bionic64',
    :forward => '9001', 
    :ram => 1024, 
    :cpus => 2, 
  },
]



$bootstrap = <<-SCRIPT
  #!/usr/bin/env bash

  set -euo pipefail # strict mode
  #set -x


  export DEBIAN_FRONTEND=noninteractive

  debug_echo() {
    echo "*********************************"
    echo "TASK: $@"
    echo "*********************************"
    echo "   "
  }

  apt_update() {
    last_update=$(stat -c %Y /var/cache/apt/pkgcache.bin)
    now=$(date +%s)
    if [ $((now - last_update)) -gt 3600 ]; then
      sudo apt-get update
    fi
  }

  apt_install() {
    apt_update

    install='no'

    perl_dpkg_find=$(cat <<'HERE'
      my $installed=0;
      my $found=0;

      my $dpkg_stdout = qx(dpkg --get-selections | grep ${pkgname} 2>/dev/null);
      my $dpkg_rc = $? >> 8;

      if ($dpkg_rc == 0) {
        $installed=1;
        $found=1;
        print "INSTALLED\n";
        exit(0);
      } 

      if ($dpkg_rc != 0) {
        my $text = "Verify that apt-cache finds it at all";
        my $apt_search_stdout = qx(sudo apt-cache search . | grep ${pkgname});

        my $apt_search_rc = $? >> 8;

        if ($apt_search_rc == 0) {
          print "NOT_INSTALLED\n";
        } else {
          print "NOT_FOUND\n";
        }
      }

HERE
    )

    for pkg in "${@}"; do
      #echo -en "*** Apt install: ||${pkg}||"
      check_pkg=$(perl -s -e "${perl_dpkg_find}" -- -pkgname="${pkg}")
      echo "*** ${check_pkg} ||${pkg}|| "

      if [[ ${check_pkg} == 'NOT_INSTALLED' ]]; then
        install='yes'
        sudo apt-get install -y "${pkg}"
      fi

    done




  }

  install_ansible() {
    local ansible_apps=(
      build-essential
      software-properties-common 
      
      gcc
      python-setuptools 
      python-pip
      python-dev 

    )

    debug_echo "Apt manual update"
    sudo apt-get update

    debug_echo "Apt install ansible prereqs"
    apt_install "${ansible_apps[@]}"

    debug_echo "Pip install ansible"
    if ! which ansible >/dev/null 2>&1; then 
      sudo pip install ansible
      #sudo pip install ansible==2.5.3
      #sudo pip install ansible==2.3.3
    fi

    debug_echo "Done installing ansible"
  }

  git_checkout_runner() {
    if [[ ! -d "$HOME/ansible-runner-scripts2" ]]; then
      echo "------ Checking out ansible-runner-scripts2 repo"
      cd "$HOME"
      git clone 'https://github.com/senorsmile/ansible-runner-scripts2.git'
    fi
  }

  install_pyenv() {

    whoami
    if ! sudo -H -u vagrant bash -i -c 'pyenv --version'; then
      echo "*-*-*-* install pyenv deps"
      sudo apt-get update
      sudo apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -qq -y install make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev python-openssl git

      echo "*-*-*-* Install pyenv"
      curl https://pyenv.run | bash
      echo -en '\nexport PATH=\"/home/vagrant/.pyenv/bin:$PATH\"\neval \"$(pyenv init -)\"\neval \"$(pyenv virtualenv-init -)\"' >> $HOME/.bashrc
    fi

    if ! sudo -H -u vagrant bash -i -c 'pyenv versions | grep 3.8.2'; then
      sudo -H -u vagrant bash -i -c 'pyenv install 3.8.2'
    fi
  }

  test_runner() {
    cd "$HOME/ansible-runner-scripts2/"
    git checkout fix-pipenv-install
    git pull --rebase
    git submodule update --init --recursive

    if [[ ! -L "$HOME/ansible-runner-scripts2/Pipfile" ]]; then
      ln -s ansible_2.9/Pipfile
    fi

    sudo -H -u vagrant bash -i -c './run_ansible.sh'
  }
  run() {
    #install_ansible
    apt_install git
    install_pyenv
    git_checkout_runner
    test_runner
  }

  time run

SCRIPT

Vagrant.configure("2") do |config|
  nodes.each do |node|
    config.vm.define node[:hostname] do |nodeconfig|
      nodeconfig.vm.box = node[:box] ? node[:box] : "ubuntu/trusty64"
      nodeconfig.vm.network :private_network, ip: node[:ip]
      nodeconfig.vm.network :forwarded_port, guest: 22, host: node[:forward], id: 'ssh'

      ## disable for wsl
      #nodeconfig.vm.synced_folder '.', '/vagrant', disabled: true


      memory = node[:ram]  ? node[:ram]  : 256;
      cpus   = node[:cpus] ? node[:cpus] : 1;

      

      nodeconfig.vm.provider :virtualbox do |vb|

        # fix for wsl
        vb.customize [ "modifyvm", :id, "--uartmode1", "disconnected" ]


        vb.customize [
          "modifyvm", :id,
          "--cpuexecutioncap", "90",
          "--cpus", cpus.to_s,
          "--memory", memory.to_s,
        ]


        #vb.gui = true

      end
    end

    config.vm.provision "shell", inline: $bootstrap, privileged: false


    ##if node[:hostname] == 'jenkins-master'
    #  config.vm.provision "ansible_local" do |ansible|
    #    ansible.playbook = "site.yml"
    #    ansible.compatibility_mode = "2.0"
    #    ansible.install = false
    #    #ansible.verbose = "vv"
    #    #ansible.become = true
    #  end
    #  #config.vm.synced_folder ".", "/vagrant"
    ##end

  end
end
