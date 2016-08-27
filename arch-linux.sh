#!/bin/sh

# http://kvz.io/blog/2013/11/21/bash-best-practices/
# sh -c "$(curl --location --silent goo.gl/XsZBK6)"

# make your script exit when a command fails 
set -o errexit

# to catch pipe fails eg. mysqldump |gzip
set -o pipefail 

# exit when your script tries to use undeclared variables 
set -o nounset

# trace what gets executed, usefull when debugging
# set -o xtrace 

if [ `find /sys/firmware/efi/efivars -prune -empty -type d`]
then
  echo -e "Script is designed to work only with UEFI system" 1>&2
  exit 1
else
  echo -e "UEFI system \e[0;32;47m [OK] \e[0m \t"
fi

# connection with Internet is required 
# wifi-menu

# enable network time synchronization
timedatectl set-ntp true

# timezones are not handle by NTP which always returns UTC time
# handling the time zone is a role of computers local OS
# http://serverfault.com/questions/194402/does-ntp-daemon-set-the-host-timezone

# set polish keyboard layout
loadkeys pl

parted /dev/sda --script mklabel gpt mkpart primary fat32 0 512MiB set boot on name "EFP with systemd-boot"
parted /dev/sda --script mklabel gpt mkpart primary 512MiB 100% set lvm "Arch LVM on LUKS"
