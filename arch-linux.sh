#!/bin/sh

# http://kvz.io/blog/2013/11/21/bash-best-practices/
# sh -c "$(curl --location https://raw.githubusercontent.com/Archetylator/scripts/master/arch-linux.sh)"

# make your script exit when a command fails 
set -o errexit

# to catch pipe fails eg. mysqldump |gzip
set -o pipefail 

# exit when your script tries to use undeclared variables 
set -o nounset

# trace what gets executed, usefull when debugging
set -o xtrace 

if [ `ls --almost-all /sys/firmware/efi/efivars` ]
then
  echo -e "UEFI system \e[0;32;47m [OK] \e[0m 0;32m \t"
else
  echo -e "Script is designed to work only with UEFI system" 1>&2
  exit 1
fi

# enable network time synchronization
timedatectl set-ntp true

# timezones are not handle by NTP which always returns UTC time
# handling the time zone is a role of computers local OS
# http://serverfault.com/questions/194402/does-ntp-daemon-set-the-host-timezone

# set polish keyboard layout
loadkeys pl

gdisk /dev/sda
