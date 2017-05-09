#!/bin/sh

# http://kvz.io/blog/2013/11/21/bash-best-practices/
# sh -c "$(curl --location --silent goo.gl/DFqadT)"

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

CHROOT="arch-chroot /mnt"

task "Set hardware clock time in UTC"
$CHROOT hwclock --systohc --utc
ok 

task "Setting system language" 
echo LANG=en_US.UTF-8 >> /etc/locale.conf 
echo LANGUAGE=en_US >> /etc/locale.conf 
echo LC_ALL=C >> /etc/locale.conf 
ok 

task "Setting host name" 
echo zalman > /mnt/etc/hostname 
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

taks "Configuring boot loader"
cat << EOF > /boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options cryptdevice=PARTLABEL=LVMonLUKS:cryptolvm root=/dev/mapper/arch-root rw
EOF

cat << EOF > /boot/loader/loader.conf
timeout 3
default arch
editor 0
EOF
ok

