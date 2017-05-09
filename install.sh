#!/bin/sh

# http://kvz.io/blog/2013/11/21/bash-best-practices/
# sh -c "$(curl --location --silent https://goo.gl/ptUyx8)"

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

MOUNTPATH="/mnt"
MOUNTHOMEPATH="$MOUNTPATH/home"
MOUNTBOOTPATH="$MOUNTPATH/boot"
CHROOT="arch-chroot $MOUNTPATH"
 
if [ `find /sys/firmware/efi/efivars -prune -empty -type d` ]
then
  echo -e "Script is designed to work only with UEFI system"
  exit 1
else
  task "UEFI system"
  result
fi

# connection with Internet is required 
# wifi-menu

task "Network time synchronization"
timedatectl set-ntp true
result

# timezones are not handle by NTP which always returns UTC time
# handling the time zone is a role of computers local OS
# http://serverfault.com/questions/194402/does-ntp-daemon-set-the-host-timezone

task "Setting polish keybourd layout"
loadkeys pl
result

read -e -p "Enter device (eg. /dev/sda):" -i "/dev/sda" DEVICE

# set GPT for device
task "Setting GPT"
parted $DEVICE --script mklabel gpt
result

task "Creating 'ESP' partition with boot flag" 
parted $DEVICE --script mkpart ESP fat32 0% 512MiB && \
parted $DEVICE --script set 1 boot on && \
parted $DEVICE --script name 1 'ESP'
result

task "Creating 'LVM on LUKS' partition"
parted $DEVICE --script mkpart primary 512MiB 100% && \
parted $DEVICE --script set 2 LVM on && \
parted $DEVICE --script name 2 'LVMonLUKS'
result 

PARTITION1=$DEVICE"1"
PARTITION2=$DEVICE"2"

read -e -s -p "Enter encryption password:" EPASS

echo -e

task "Encrypting 'LVM on LUKS' partition"
echo $EPASS | cryptsetup --cipher aes-xts-plain64 --key-size 512 --hash sha512 --use-random luksFormat $PARTITION2 -d -
result

task "Opening LUKS on 'LVM on LUKS' partition and mapping as 'luks'"
echo $EPASS | cryptsetup luksOpen $PARTITION2 luks -d -
result

task "Creating physical volume on 'luks'"
pvcreate /dev/mapper/luks &> /dev/null 
result 

task "Creating volume group named 'arch' on 'luks'"
vgcreate arch /dev/mapper/luks &> /dev/null 
result

read -e -p "Enter size for swap partition:" -i "8G" SWAPSIZE
task "Creating virtual volume named 'swap' in 'arch' group"
lvcreate --size $SWAPSIZE arch --name swap &> /dev/null 
result

read -e -p "Enter size for home partition:" -i "50G" HOMESIZE
task "Creating virtual volume named 'home' in 'arch' group"
lvcreate --size $HOMESIZE arch --name home &> /dev/null 
result 

task "Creating virtual volume named 'root' in 'arch' group"
lvcreate -l +100%FREE arch --name root &> /dev/null 
result 

task "Setting fat32 on ESP partition"
mkfs.vfat -F32 $PARTITION1 &> /dev/null 
result

task "Setting ext4 on 'root' virtual volume"
mkfs.ext4 /dev/mapper/arch-root &> /dev/null 
result

task "Setting ext4 on 'home' virtual volume"
mkfs.ext4 /dev/mapper/arch-home &> /dev/null
result 

task "Setting swap on 'swap' virtual volume"
mkswap /dev/mapper/arch-swap &> /dev/null
result

task "Mounting 'arch-root' under '/mnt'"
mount /dev/mapper/arch-root $MOUNTPATH
result

task "Mounting 'arch-swap'"
swapon /dev/mapper/arch-swap
result

task "Mounting 'arch-home' under '/mnt/home'"
mkdir $MOUNTHOMEPATH && \
mount /dev/mapper/arch-home $MOUNTHOMEPATH
result

task "Mounting ESP under '/mnt/boot'"
mkdir $MOUNTBOOTPATH && \
mkdir $MOUNTBOOTPATH/EFI && \
mount $PARTITION1 $MOUNTBOOTPATH
result

task "Installing base system"
pacstrap $MOUNTPATH base base-devel efibootmgr &> /dev/null
result

task "Generating fstab file"
genfstab -pU $MOUNTPATH >> $MOUNTPATH/etc/fstab
result

task "Set hardware clock time in UTC"
$CHROOT hwclock --systohc --utc
result 

task "Setting system language" 
echo LANG=en_US.UTF-8 >> $MOUNTPATH/etc/locale.conf && \
echo LANGUAGE=en_US >> $MOUNTPATH/etc/locale.conf && \
echo LC_ALL=C >> $MOUNTPATH/etc/locale.conf 
result 

task "Setting host name" 
echo arch > $MOUNTPATH/etc/hostname 
result 

task "Setting root password" 
echo -e
$CHROOT passwd --quiet
result 

task "Adding 'encrypt lvm2' to MODULES AND 'ext4' to HOOKS in '/etc/mkinitcpio.conf'" 
sed -i 's/^MODULES=.*/MODULES="ext4"/' $MOUNTPATH/etc/mkinitcpio.conf && \
sed -i 's/^HOOKS=.*/HOOKS="base udev autodetect modconf keyboard block encrypt lvm2 filesystems fsck"/' $MOUNTPATH/etc/mkinitcpio.conf 
result

task "Creating a new initial RAM disk"
$CHROOT mkinitcpio -p linux &> /dev/null
result 

task "Installing systemd-boot" 
$CHROOT bootctl install &> /dev/null
result

task "Creating boot loader entry"
cat << EOF > $MOUNTPATH/boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options cryptdevice=PARTLABEL=LVMonLUKS:cryptolvm root=/dev/mapper/arch-root rw
EOF
result

task "Configuring boot loader"
cat << EOF > $MOUNTPATH/boot/loader/loader.conf
timeout 3
default arch
editor 0
EOF

cat << EOF > $MOUNTPATH/etc/pacman.d/hooks/systemd-boot.hook
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Updating systemd-boot...
When = PostTransaction
Exec = /usr/bin/bootctl update
EOF
result

confirm "Unmount and reboot [y/N]:" && umount -R /mnt && reboot

