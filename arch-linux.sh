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

function task {
  echo -n $1
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
task "Setting GPT"
parted $DEVICE --script mklabel gpt
ok

task "Creating 'ESP with systemd-boot' partition with boot flag" 
parted $DEVICE --script mkpart ESP fat32 0% 512MiB
parted $DEVICE --script set 1 boot on 
parted $DEVICE --script name 1 'ESP with systemd-boot'
ok

task "Creating 'LVM on LUKS' partition"
parted $DEVICE --script mkpart primary 512MiB 100% 
parted $DEVICE --script set 2 LVM on 
parted $DEVICE --script name 2 'Arch LVM on LUKS'
ok 

PARTITION1=$DEVICE"1"
PARTITION2=$DEVICE"2"

task "Encrypting 'LVM on LUKS' partition"
#read -e -p "Enter password for LUKS:" PASSWORD
cryptsetup --cipher aes-xts-plain64 --use-random luksFormat $PARTITION2
ok

task "Opening LUKS on 'LVM on LUKS' partition and mapping as 'luks'"
cryptsetup luksOpen $PARTITION2 luks
ok

task "Creating physical volume on 'luks'"
pvcreate /dev/mapper/luks
ok 

task "Creating volume group named 'swap' on 'luks'"
vgcreate arch /dev/mapper/luks
ok

read -e -p "Enter size for swap partition:" -i "8G" SWAPSIZE
task "Creating virtual volume named 'swap' in 'arch' group"
lvcreate --size $SWAPSIZE arch --name swap
ok

read -e -p "Enter size for home partition:" -i "50G" HOMESIZE
task "Creating virtual volume named 'home' in 'arch' group"
lvcreate --size $HOMESIZE arch --name home
ok 

task "Creating virtual volume named 'root' in 'arch' group"
lvcreate -l +100%FREE arch --name root
ok 

task "Setting ext4 on 'root' virtual volume"
mkfs.ext4 /dev/mapper/arch-root
ok

task "Setting ext4 on 'home' virtual volume"
mkfs.ext4 /dev/mapper/arch-home
ok 

task "Setting swap on 'swap' virtual volume"
mkswap /dev/mapper/arch-swap
ok

task "Mounting 'arch-root' under '/mnt'"
mount /dev/mapper/arch-root /mnt
ok

task "Mounting 'arch-swap'"
swapon /dev/mapper/arch-swap
ok

task "Mounting 'arch-home' under '/mnt/home'"
mkdir /mnt/home
mount /dev/mapper/arch-home /mnt/home
ok

task "Mounting ESP under '/mnt/boot'"
mkdir /mnt/boot
mkdir /mnt/boot/EFI
mount $PARTITION1 /mnt/boot
ok

task "Installing base system"
pacstrap /mnt base base-devel vim git efibootmgr dialog wpa_supplicant
ok

task "Generating fstab file"
genfstab -pU /mnt >> /mnt/etc/fstab
ok

cat << EOF | arch-chroot /mnt
task "Setting local time zone" /
ln -s /usr/share/zoneinfo/Europe/Sofia /etc/localtime /
hwclock --systohc --utc /
ok /
task "Setting system language" /
echo LANG=en_US.UTF-8 >> /etc/locale.conf /
echo LANGUAGE=en_US >> /etc/locale.conf /
echo LC_ALL=C >> /etc/locale.conf /
ok /
task "Setting host name" /
echo zalman > /etc/hostname /
ok /
task "Setting root password" /
passwd /
ok /
task "Adding 'encrypt lvm2' to MODULES AND 'ext4' to HOOKS in '/etc/mkinitcpio.conf'" /
sed -i 's/\bMODULES="\b/&ext4 /' /etc/mkinitcpio.conf /
sed -i 's/\bHOOKS="\b/&encrypt lvm2 /' /etc/mkinitcpio.conf /
ok /
task "Creating a new initial RAM disk" /
mkinitcpio -p linux /
ok /
task "Installing systemd-boot" /
bootctl --path=$PARTITION1 install /
ok /
EOF
