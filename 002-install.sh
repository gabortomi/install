#!/bin/bash

#set -e

###############################################################################

# Author	:	Tamas Gabor

###############################################################################

# Command
arch_chroot() {
    arch-chroot /mnt /bin/bash -c "${1}"
}

# Copy files from Github
arch_chroot "mkdir -p /mnt/mnt/etc/skel"
arch_chroot "git clone https://github.com/gabortomi/tom-bspwm.git /mnt/mnt/etc/skel/"
arch_chroot "cp -rfT /mnt/mnt/etc/skel/ /etc/skel/"

# Fstab
genfstab -p /mnt >> /mnt/etc/fstab

cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

echo "" >> /mnt/etc/pacman.conf;echo "[multilib]" >> /mnt/etc/pacman.conf;echo "Include = /etc/pacman.d/mirrorlist" >> /mnt/etc/pacman.conf
arch_chroot "pacman -Syy"

# Time Zone
arch_chroot "ln -s /usr/share/zoneinfo/Europe/Budapest /etc/localtime"
arch_chroot "hwclock --systohc --utc"

