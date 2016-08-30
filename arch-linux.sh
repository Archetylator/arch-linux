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

function ok {
  echo -e $1" \e[0;32;47m [OK] \e[0m \t"
}

if [ `find /sys/firmware/efi/efivars -prune -empty -type d`]
then
  echo -e "Script is designed to work only with UEFI system" 1>&2
  exit 1
else
  ok "UEFI system"
fi

# connection with Internet is required 
# wifi-menu

timedatectl set-ntp true
ok "Network time synchronization"

# timezones are not handle by NTP which always returns UTC time
# handling the time zone is a role of computers local OS
# http://serverfault.com/questions/194402/does-ntp-daemon-set-the-host-timezone

loadkeys pl
ok "Set polish keybourd layout"

read -e -p "Enter device (eg. /dev/sda):" -i "/dev/sda" DEVICE

# set GPT for device
parted $DEVICE --script mklabel gpt
ok "Set GPT"

parted $DEVICE --script mkpart primary fat32 0% 512MiB
parted $DEVICE --script set 1 boot on 
parted $DEVICE --script name 1 'EFP with systemd-boot'
ok "Created 'EFP with systemd-boot' partition with boot flag"

parted $DEVICE --script mkpart primary 512MiB 100% 
parted $DEVICE --script set 2 LVM on 
parted $DEVICE --script name 2 'Arch LVM on LUKS'
ok "Created 'LVM on LUKS' partition"

PARTITION1=$DEVICE"1"
PARTITION2=$DEVICE"2"

mkfs.vfat -F32 $PARTITION1
ok "Set fat32 on EFP partition"

read -e -p "Enter password for LUKS:" PASSWORD
(echo YES; echo $PASSWORD; echo $PASSWORD) | cryptsetup --cipher aes-xts-plain64 --use-random luksFormat $PARTITION2
ok "Encrypted 'LVM on LUKS' partition"

cryptsetup luksOpen $PARTITION2 luks
ok "Opened LUKS on 'LVM on LUKS' partition and mapped as 'luks'"

pvcreate /dev/mapper/luks
ok "Created physical volume on 'luks'"

vgcreate arch /dev/mapper/luks
ok "Created volume group named 'swap' on 'luks'"

read -e -p "Enter size for swap partition:" -i "8G" SWAPSIZE
lvcreate --size $SWAPSIZE arch --name swap
ok "Created virtual volume named 'swap' in 'arch' group"

read -e -p "Enter size for home partition:" -i "50G" HOMESIZE
lvcreate --size $HOMESIZE arch --name home
ok "Created virtual volume named 'home' in 'arch' group"

lvcreate -l +100%FREE arch --name root
ok "Created virtual volume named 'root' in 'arch' group"

mkfs.ext4 /dev/mapper/arch-root
ok "Set ext4 on 'root' virtual volume"

mkfs.ext4 /dev/mapper/arch-home
ok "Set ext4 on 'home' virtual volume"

mkswap /dev/mapper/arch-swap
ok "Set swap on 'swap' virtual volume"

mount /dev/mapper/arch-root /mnt
ok "Mounted 'arch-root' under '/mnt'"

swapon /dev/mapper/arch-swap
ok "Mounted 'arch-swap'"

mkdir /mnt/home
mount /dev/mapper/arch-home /mnt/home
ok "Mounted 'arch-home' under '/mnt/home'"

mkdir /mnt/boot
mkdir /mnt/boot/EFI
mount $PARTITION1 /mnt/boot
ok "Mounted ESP under '/mnt/boot'"

pacstrap /mnt base base-devel vim git efibootmgr dialog wpa_supplicant
ok "Installed base system"

genfstab -pU /mnt >> /mnt/etc/fstab
ok "Generated fstab file"

arch-chroot /mnt /bin/bash
ok "Chroot into new system"

ln -s /usr/share/zoneinfo/Europe/Sofia /etc/localtime
hwclock --systohc --utc
ok "Set local time zone"

echo LANG=en_US.UTF-8 >> /etc/locale.conf
echo LANGUAGE=en_US >> /etc/locale.conf
echo LC_ALL=C >> /etc/locale.conf
ok "Set system language"

echo zalman > /etc/hostname
ok "Set host name"

passwd
ok "Set root password"

sed -i 's/\bMODULES="\b/&ext4 /' /etc/mkinitcpio.conf
sed -i 's/\bHOOKS="\b/&encrypt lvm2 /' /etc/mkinitcpio.conf
ok "Added 'encrypt lvm2' to MODULES AND 'ext4' to HOOKS in '/etc/mkinitcpio.conf'"

mkinitcpio -p linux
ok "Create a new initial RAM disk"

bootctl --path=$PARTITION1 install
ok "Installed systemd-boot"
