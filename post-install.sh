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

INSTALL="pacman -Syu --noconfirm --quiet"

task "Enabling dhcpcd"
systemctl enable dhcpcd &> /dev/null && \ 
systemctl start dhcpcd &> /dev/null 
result

# If virtualbox
task "Virtualbox"
$INSTALL virtualbox-host-modules-arch virtualbox-guest-utils
systemctl enable vboxservice 
systemctl start vboxservice 
result

task "Installing additional packages"
$INSTALL << EOF 
adwaita-icon-theme base-devel chromium cups cups-pdf eog evince file-roller 
firefox gedit gimp gnome-calculator gnome-control-center gnome-screenshot 
gnome-session gnome-settings-daemon gnome-shell gnome-terminal gtk3-print-backends 
keepass libreoffice-still mutter nautilus sudo virtualbox vlc 
xorg-server xorg-xinit 
EOF
result

read -e -p "Enter your user name:" -i "jack" SUSER

task "Creating $SUSER"
useradd -m -g users -s /bin/bash $SUSER 
result 

read -s -p "Enter your user password:" UPASS
echo -e

task "Setting standard user password" 
echo "$SUSER:$UPASS" | chpasswd
result 

unset UPASS

task "Adding user to sudoers"
echo "$SUSER  ALL=(ALL:ALL) ALL" >> /etc/sudoers
result

task "Locking root user"
passwd -l root &> /dev/null
result
