#!/bin/sh

# http://kvz.io/blog/2013/11/21/bash-best-practices/
# sh -c "$(curl --location --silent https://goo.gl/PSeJNd)"

# make your script exit when a command fails 
# set -o errexit

# exit when your script tries to use undeclared variables 
# set -o nounset

# trace what gets executed, usefull when debugging
# set -o xtrace

function task {
  echo -n $1
}

function result {
  if [[ $? -eq 0 ]]; then
    echo -e " \e[0;32;47m [OK] \e[0m \t"
  else
    echo -e " \e[0;31;47m [FAIL] \e[0m \t"
  fi
}

function confirm {
  read -r -p "${1:-Are you sure? [y/N]} " response
  case "$response" in
    [yY][eE][sS]|[yY]) 
        true
        ;;
    *)
        false
        ;;
  esac
}

task "Installing additional packages"
pacman -S sudo &> /dev/null
result

read -e -p "Enter your user name:" -i "jack" SUSER

task "Creating $SUSER"
$CHROOT useradd -m -g users -s /bin/bash $SUSER 
result 

read -s -p "Enter your user password:" UPASS
echo -e

task "Setting standard user password" 
echo '$SUSER:$UPASS' | chpasswd
result 

unset UPASS

task "Adding user to sudoers"
echo '$SUSER  ALL=(ALL:ALL) ALL' >> /etc/sudoers
result

task "Locking root user"
passwd -l root &> /dev/null
result
