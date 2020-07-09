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

rootuuid=$(lsblk -lno UUID /dev/sda2)

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
arch_chroot "export LANG=hu_HU.UTF-8"
arch_chroot "locale > /etc/locale.conf"

echo "KEYMAP=hu"  > /mnt/etc/vconsole.conf

# Hostname
arch_chroot "echo archbook > /etc/hostname"

# Hosts
echo "127.0.0.1	localhost" >> /mnt/etc/hosts;echo "::1		localhost" >> /mnt/etc/hosts;echo "127.0.1.1	archbook.localdomain	archbook" >> /mnt/etc/hosts

# Install basic apps (Xorg, Pulseaudio, ...)
arch_chroot "pacman -S --noconfirm --needed xorg-server xorg-apps xorg-xinit xorg-twm alsa-utils xorg-xbacklight pulseaudio pulseaudio-alsa xf86-input-libinput networkmanager xdg-user-dirs xdg-utils gvfs gvfs-mtp man-db neofetch xf86-video-fbdev bash-completion"
arch_chroot "systemctl enable NetworkManager"

# Mkinitcpio
arch_chroot "mkinitcpio -p linux"

# Root passwd
arch_chroot "passwd"

# Boot loader
pacstrap /mnt refind-efi efibootmgr
arch_chroot "refind-install"
echo "\"ArchBook Linux\" \"root=UUID=${rootuuid} rw add_efi_memmap\"" > /mnt/boot/refind_linux.conf
echo "\"ArchBook Linux Fallback\" \"root=UUID=${rootuuid} rw add_efi_memmap initrd=/initramfs-linux-fallback.img\"" >> /mnt/boot/refind_linux.conf
echo "\"ArchBook Linux Terminal\" \"root=UUID=${rootuuid} rw add_efi_memmap systemd.unit=multi-user.target\"" >> /mnt/boot/refind_linux.conf

# Add a user
arch_chroot "useradd -m -g users -G adm,lp,wheel,power,audio,video -s /bin/bash $user_name"
echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers
arch_chroot "passwd $user_name"

# Yay
arch_chroot "cd /home/${user_name} ; su ${user_name} -c 'git clone https://aur.archlinux.org/yay-bin' ; cd yay-bin ; su ${user_name} -c 'makepkg' ; pacman -U yay-bin*x86_64* --noconfirm ; cd .. ; rm -rf yay-bin"


# Install VGA
arch_chroot "xf86-video-intel libva-intel-driver lib32-mesa"

# Install desktop
arch_chroot "cd /home/${user_name} ; su ${user_name} -c 'yay -S --noconfirm --needed  xtitle-git sutils-git polybar dmenu2'"
arch_chroot "pacman -S --noconfirm --needed  bspwm sxhkd firefox firefox-i18n-hu alacritty picom dunst neovim pcmanfm zathura zathura-pdf-poppler zathura-ps zathura-djvu redshift intel-ucode ttf-jetbrains-mono ttf-font-awesome discord rofi cronie"
arch_chroot "rm -rf /mnt/mnt"
arch_chroot "cd /home/$user_name/; rm -rf .git/ LICENSE README.md git.sh setup-git.sh "




