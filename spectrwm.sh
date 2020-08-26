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

# Check password
pass_check() {

    echo "RUN PASS CHECK FUNCTION"

    user_name=$1
    userpass1=$2
    userpass2=$3
    rootpass1=$4
    rootpass2=$5
    
    if [ "$userpass1" != "$userpass2" ]
    then
        yad --image=error --title="$TITLE"  --buttons-layout=center --text="$ERR_USER_PASS"
        echo "Not same user password"
        user_root_set
    elif [ "$rootpass1" != "$rootpass2" ]
    then
        yad --image=error --title="$TITLE" --buttons-layout=center --text="$ERR_ROOT_PASS"
        echo "Not same root password"
        user_root_set
    fi
}

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

dd if=/dev/zero of=/mnt/swapfile bs=1M count=4096
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile
swapfile="yes"

# Select the mirrors
pacman -Sy --needed --noconfirm reflector
reflector --verbose -l 20 -p https --sort rate --save /etc/pacman.d/mirrorlist

# INstall the BASE and BASE-DEVEL packages
    pacstrap /mnt base base-devel linux linux-firmware git
    echo "end base"
# Copy files from Github
    arch_chroot "mkdir -p /mnt/mnt/etc/skel"
    arch_chroot "git clone https://github.com/gabortomi/tom-spectrwm.git /mnt/mnt/etc/skel/"
    arch_chroot "cp -rfT /mnt/mnt/etc/skel/ /etc/skel/"

# Fstab
    genfstab -p /mnt >> /mnt/etc/fstab

    cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
    echo "" >> /mnt/etc/pacman.conf;echo "[multilib]" >> /mnt/etc/pacman.conf;echo "Include = /etc/pacman.d/mirrorlist" >> /mnt/etc/pacman.conf
    
    arch_chroot "pacman -Syy"

    echo "# $INS002"
    touch .passwd
    echo -e "$rootpass1\n$rootpass2" > .passwd
    arch_chroot "passwd root" < .passwd >/dev/null
    rm .passwd

# Add a user
    arch_chroot "useradd -m -g users -G adm,lp,wheel,power,audio,video -s /bin/bash $user_name"
    echo -e "$userpass1\n$userpass2" > .passwd
    arch_chroot "passwd $user_name" < .passwd >/dev/null
    rm .passwd
    echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers
#arch_chroot "passwd $user_name"

# Locale
    echo "hu_HU.UTF-8 UTF-8" >> /mnt/etc/locale.gen
    echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
    arch_chroot "locale-gen"
    export LANG=hu_HU.UTF-8
    locale > /mnt/etc/locale.conf

    echo "KEYMAP=hu"  > /mnt/etc/vconsole.conf
    
   
# Time Zone
    arch_chroot "ln -s /usr/share/zoneinfo/Europe/Budapest /etc/localtime"
    arch_chroot "hwclock --systohc --utc"
    arch_chroot "timedatectl set-ntp true"



# Hostname
    arch_chroot "echo archbook > /etc/hostname"

# Hosts
# echo "127.0.0.1	localhost" >> /mnt/etc/hosts;echo "::1		localhost" >> /mnt/etc/hosts;echo "127.0.1.1	archbook.localdomain	archbook" >> /mnt/etc/hosts

# Install basic apps (Xorg, Pulseaudio, ...)
arch_chroot "pacman -S --noconfirm --needed xorg-server xorg-apps xorg-xinit xorg-twm xterm alsa-utils pulseaudio pulseaudio-alsa xf86-input-libinput networkmanager xdg-user-dirs xdg-utils gvfs gvfs-mtp man-db neofetch acpi xf86-video-fbdev bash-completion  xorg-xbacklight"
arch_chroot "systemctl enable NetworkManager"

# Yay
arch_chroot "cd /home/${user_name} ; su ${user_name} -c 'git clone https://aur.archlinux.org/yay-bin' ; cd yay-bin ; su ${user_name} -c 'makepkg' ; pacman -U yay-bin*x86_64* --noconfirm ; cd .. ; rm -rf yay-bin"

processor=$(lspci -n | awk -F " " '{print $2 $3}' | grep ^"06" | awk -F ":" '{print $2}' | sed -n  '1p')

if [ "$processor" = "8086" ]
then
    pacstrap /mnt intel-ucode
elif [ "$processor" = "1022" ]
then
    pacstrap /mnt amd-ucode
fi

# Install VGA
arch_chroot "pacman -S --noconfirm --needed xf86-video-intel libva-intel-driver lib32-mesa"

# Install Theme and background    
    git clone https://github.com/magyarchlinux/magyarch_xfce4.git
    mkdir -p /mnt/usr/share/backgrounds
    cp -rf magyarch_xfce4/usr/share/backgrounds/magyarch/ /mnt/usr/share/backgrounds/
    cp -rf magyarch_xfce4/usr/share/themes/MagyArch-dark /mnt/usr/share/themes/        
    cp -rf magyarch_xfce4/usr/share/themes/MagyArch-braincolor /mnt/usr/share/themes/""


# Install desktop
    arch_chroot "pacman -S --noconfirm --needed spectrwm unclutter dunst picom polkit-gnome rxvt-unicode urxvt-perls dmenu rofi firefox firefox-i18n-hu scrot vifm pcmanfm discord lxappearance zathura zathura-djvu zathura-pdf-poppler ttf-joypixels ttf-jetbrains-mono terminus-font neofetch feh htop neovim xwallpaper sxhkd alacritty wmctrl reflector noto-fonts-emoji redshift"
    arch_chroot "LANG=C ; yes | pacman -S libxft-bgra "
#arch_chroot "git clone https://github.com/bazeeel/st.git /mnt/mnt/st; cd /mnt/mnt/st; make clean install"
#arch_chroot "rm -rf /mnt/mnt"
#arch_chroot "cd /home/$user_name/; rm -rf .git/ LICENSE README.md git.sh setup-git.sh "


# Set makepkg.conf
    sed -i 's/#MAKEFLAGS="-j[0-9]"/MAKEFLAGS="-j'$(nproc)'"/;s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T '$(nproc)' -z -)/;s/COMPRESSZST=(zstd -c -z -q -)/COMPRESSZST=(zstd -c -T'$(nproc)' -z -q -)/' /mnt/etc/makepkg.conf

# Boot loader
pacstrap /mnt grub efibootmgr
arch_chroot "grub-install --target=x86_64-efi --efi-directory=/boot/efi"
arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"

# Check Laptop
    if [ -z "$(ls -A /sys/class/power_supply/)" -o "$(ls -A /sys/class/power_supply)" = "AC" ]
    then
        echo "No Laptop"
    else
        echo "Laptop"
        cp /installer/40-libinput.conf /mnt/etc/X11/xorg.conf.d/
    fi

# Mkinitcpio
    arch_chroot "mkinitcpio -p linux"

cp -rf install/75-noto-color-emoji.conf /mnt/etc/fonts/conf.avail/

umount -R /mnt



