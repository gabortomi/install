#!/bin/bash

#set -e

###############################################################################

# Author	:	Tamas Gabor

###############################################################################

# UPDATE THE SYSTEM CLOCK
timedatectl set-ntp true

# Format the partition
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2

# Mount the filesystem
mount /dev/sda2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi
touch /mnt/swapfile

dd if=/dev/zero of=/mnt/swapfile bs=1M count=2048
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile
swapfile="yes"

# Select the mirrors
pacman -Sy --needed --noconfirm reflector
reflector --verbose -l 20 -p https --sort rate --save /etc/pacman.d/mirrorlist

# INstall the BASE and BASE-DEVEL packages
pacstrap /mnt base base-devel linux linux-firmware git

echo
echo
echo "Base install done"
echo
echo

#!/bin/bash

#set -e

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
export LANG=hu_HU.UTF-8
locale > /mnt/etc/locale.conf

echo "KEYMAP=hu"  > /mnt/etc/vconsole.conf

echo
echo
echo "locale done"
echo
echo

# Hostname
arch_chroot "echo archbook > /etc/hostname"

# Hosts
# echo "127.0.0.1	localhost" >> /mnt/etc/hosts;echo "::1		localhost" >> /mnt/etc/hosts;echo "127.0.1.1	archbook.localdomain	archbook" >> /mnt/etc/hosts

# Install basic apps (Xorg, Pulseaudio, ...)
arch_chroot "pacman -S --noconfirm --needed xorg-server xorg-appres xorg-xinit xorg-twm alsa-utils xorg-xbacklight pulseaudio pulseaudio-alsa xf86-input-libinput networkmanager xdg-user-dirs xdg-utils gvfs gvfs-mtp man-db neofetch xf86-video-fbdev bash-completion"
arch_chroot "systemctl enable NetworkManager"

# Mkinitcpio
arch_chroot "mkinitcpio -p linux"

# Root passwd
#arch_chroot "passwd"

# Boot loader
pacstrap /mnt grub efibootmgr
arch_chroot "grub-install --target=x86_64-efi --efi-directory=/boot/efi"
arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"

echo
echo
echo "Bootloader installed"
echo
echo

# Add a user
arch_chroot "useradd -m -g users -G adm,lp,wheel,power,audio,video -s /bin/bash $user_name"
echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers

echo
echo 
echo "User added"
echo
echo

# Yay
git clone https://github.com/gabortomi/important-docs.git
arch_chroot "cd /home/${user_name} ; su ${user_name} -c 'git clone https://github.com/gabortomi/important-docs.git'  ; cd important-docs ; su ${user_name} -c ; pacman -U yay-10* --noconfirm ; cd .. ; rm -rf important-docs"


#arch_chroot "cd /home/${user_name} ; su ${user_name} -c 'git clone https://aur.archlinux.org/yay-bin' ; cd yay-bin ; su ${user_name} -c 'makepkg' ; pacman -U yay-bin*x86_64* --noconfirm ; cd .. ; rm -rf yay-bin"

processor=$(lspci -n | awk -F " " '{print $2 $3}' | grep ^"06" | awk -F ":" '{print $2}' | sed -n  '1p')

if [ "$processor" = "8086" ]
then
    pacstrap /mnt intel-ucode
elif [ "$processor" = "1022" ]
then
    pacstrap /mnt amd-ucode
fi

# Install VGA
arch_chroot "xf86-video-intel libva-intel-driver lib32-mesa"

# Install desktop
#arch_chroot "cd /home/${user_name} ; su ${user_name} -c ; yay -S --noconfirm --needed  xtitle-git sutils-git polybar dmenu2 "
arch_chroot "pacman -S --noconfirm --needed  bspwm sxhkd firefox firefox-i18n-hu alacritty picom dunst neovim pcmanfm-gtk3 zathura zathura-pdf-poppler zathura-ps zathura-djvu redshift ttf-jetbrains-mono ttf-font-awesome discord rofi cronie polkit-gnome feh unclutter python-gobject reflector noto-fonts-emoji"
arch_chroot "rm -rf /mnt/mnt"
arch_chroot "cd /home/$user_name/; rm -rf .git/ LICENSE README.md git.sh setup-git.sh "

cd ..

git clone https://github.com/magyarchlinux/magyarch_xfce4.git 
mkdir -p /mnt/usr/share/backgrounds
cp -rf magyarch_xfce4/usr/share/backgrounds/magyarch/ /mnt/usr/share/backgrounds/

git clone https://github.com/gabortomi/important-docs.git
cp -rf important-docs/75-noto-color-emoji.conf /mnt/etc/fonts/conf.avail/
cp -rf important-docs/30-touchpad.conf /mnt/etc/X11/xorg.conf.d/

