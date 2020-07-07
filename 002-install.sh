#!/bin/bash

#set -e

###############################################################################

# Author	:	Tamas Gabor

###############################################################################

# Command
arch_chroot() {
    arch-chroot /mnt /bin/bash -c "${1}"
}

user_name=tamas

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

# Locale
echo "hu_HU.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
arch_chroot "locale-gen"
export LANG=hu_HU.UTF-8

echo "KEYMAP=\"hu\""  > /mnt/etc/vconsole.conf

# Hostname
arch_chroot "echo archbook > /etc/hostname"

# Hosts
echo "127.0.0.1	localhost" >> /mnt/etc/hosts;echo "::1		localhost" >> /mnt/etc/hosts;echo "127.0.1.1	archbook.localdomain	archbook" >> /mnt/etc/hosts

# Install basic apps (Xorg, Pulseaudio, ...)
arch_chroot "pacman -S --noconfirm --needed xorg-server xorg-apps xorg-xinit xorg-twm alsa-utils pulseaudio pulseaudio-alsa xf86-input-libinput networkmanager xdg-user-dirs xdg-utils gvfs gvfs-mtp man-db neofetch xf86-video-fbdev"

# Mkinitcpio
arch_chroot "mkinitcpio -p linux"

# Root passwd
arch_chroot "passwd"

# Boot loader
pacstrap /mnt refind-efi efibootmgr
arch_chroot "refind-install"


# Add a user
arch_chroot "useradd -m -g users -G adm,lp,wheel,power,audio,video -s /bin/bash $user_name"




# Yay
arch_chroot "cd /home/${user_name} ; su ${user_name} -c 'git clone https://aur.archlinux.org/yay-bin' ; cd yay-bin ; su ${user_name} -c 'makepkg' ; pacman -U yay-bin*x86_64* --noconfirm ; cd .. ; rm -rf yay-bin"



