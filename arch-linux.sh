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

read -e -p "Enter device (eg. /dev/sda):" -i "/dev/sda" DEVICE

parted $DEVICE --script mkpart primary fat32 0% 512MiB
parted $DEVICE --script mklabel gpt 
parted $DEVICE --script set 1 boot on 
parted $DEVICE --script name 1 "EFP with systemd-boot"

parted $DEVICE --script mkpart primary 512MiB 100% 
parted $DEVICE --script mklabel gpt 
parted $DEVICE --script set 2 LVM on 
parted $DEVICE --script name 2 "Arch LVM on LUKS"
