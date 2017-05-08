#!/bin/sh

# http://kvz.io/blog/2013/11/21/bash-best-practices/
# sh -c "$(curl --location --silent goo.gl/XsZBK6)"

# make your script exit when a command fails 
set -o errexit

# exit when your script tries to use undeclared variables 
set -o nounset

# trace what gets executed, usefull when debugging
# set -o xtrace

function ok {
  echo -e " \e[0;32;47m [OK] \e[0m \t"
}

function task {
  echo -n $1
}

task "Set hardware clock time in UTC"
hwclock --systohc --utc
ok 

task "Setting system language" 
echo LANG=en_US.UTF-8 >> /etc/locale.conf 
echo LANGUAGE=en_US >> /etc/locale.conf 
echo LC_ALL=C >> /etc/locale.conf 
ok 

task "Setting host name" 
echo zalman > /etc/hostname 
ok 

task "Setting root password" 
passwd
ok 

task "Adding 'encrypt lvm2' to MODULES AND 'ext4' to HOOKS in '/etc/mkinitcpio.conf'" 
sed -i 's/\bMODULES="\b/&ext4 /' /etc/mkinitcpio.conf 
sed -i 's/\bHOOKS="\b/&encrypt lvm2 /' /etc/mkinitcpio.conf 
ok

task "Creating a new initial RAM disk"
mkinitcpio -p linux 
ok 

task "Installing systemd-boot" 
bootctl install 
ok

