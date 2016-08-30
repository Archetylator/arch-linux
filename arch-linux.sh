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

# set GPT for device
parted $DEVICE --script mklabel gpt

parted $DEVICE --script mkpart primary fat32 0% 512MiB
parted $DEVICE --script set 1 boot on 
parted $DEVICE --script name 1 'EFP with systemd-boot'

parted $DEVICE --script mkpart primary 512MiB 100% 
parted $DEVICE --script set 2 LVM on 
parted $DEVICE --script name 2 'Arch LVM on LUKS'

PARTITION1=$DEVICE"1"
PARTITION2=$DEVICE"2"

mkfs.vfat -F32 $PARTITION1

cryptsetup --cipher aes-xts-plain64 --verify-passphrase --use-random luksFormat $PARTITION2
cryptsetup luksOpen $PARTITION2 luks

pvcreate /dev/mapper/luks
vgcreate arch /dev/mapper/luks

read -e -p "Enter size for swap partition:" -i "8G" SWAPSIZE
lvcreate --size $SWAPSIZE arch --name swap

read -e -p "Enter size for home partition:" -i "50G" HOMESIZE
lvcreate --size $HOMESIZE arch --name home

lvcreate -l +100%FREE arch --name root

mkfs.ext4 /dev/mapper/arch-root
mkfs.ext4 /dev/mapper/arch-home
mkswap /dev/mapper/arch-swap

mount /dev/mapper/arch-root /mnt

swapon /dev/mapper/arch-swap

mkdir /mnt/home
mount /dev/mapper/arch-home /mnt/home

mkdir /mnt/boot
mkdir /mnt/boot/EFI
mount $PARTITION1 /mnt/boot

pacstrap /mnt base base-devel vim git efibootmgr dialog wpa_supplicant

genfstab -pU /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash

ln -s /usr/share/zoneinfo/Europe/Sofia /etc/localtime
hwclock --systohc --utc

echo LANG=en_US.UTF-8 >> /etc/locale.conf
echo LANGUAGE=en_US >> /etc/locale.conf
echo LC_ALL=C >> /etc/locale.conf

echo zalman > /etc/hostname

passwd

sed -i 's/\bMODULES="\b/&ext4 /' /etc/mkinitcpio.conf
sed -i 's/\bHOOKS="\b/&encrypt lvm2 /' /etc/mkinitcpio.conf

mkinitcpio -p linux

bootctl --path=$PARTITION1 install
