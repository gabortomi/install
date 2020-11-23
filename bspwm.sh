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

# Install the BASE and BASE-DEVEL packages
    pacstrap /mnt base base-devel linux linux-firmware git
    echo "end base"

# Copy files from Github
    arch_chroot "mkdir -p /mnt/mnt/etc/skel"
    arch_chroot "git clone https://github.com/gabortomi/tom-bspwm.git /mnt/mnt/etc/skel/"
    arch_chroot "cp -rfT /mnt/mnt/etc/skel/ /etc/skel/"

# Fstab
    genfstab -p /mnt >> /mnt/etc/fstab

    cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
    echo "" >> /mnt/etc/pacman.conf;echo "[multilib]" >> /mnt/etc/pacman.conf;echo "Include = /etc/pacman.d/mirrorlist" >> /mnt/etc/pacman.conf
    
    arch_chroot "pacman -Syy"

    arch_chroot "passwd root"

# Add a user
    arch_chroot "useradd -m -g users -G adm,lp,wheel,power,audio,video -s /bin/bash $user_name"
    echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers
    arch_chroot "passwd $user_name"

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
# echo "127.0.0.1	localhost" >> /mnt/etc/hosts;echo "::1		localhost" >> /mnt/etc/hosts;echo "127.0.0.1	archbook.localdomain	archbook" >> /mnt/etc/hosts

# Install basic apps (Xorg, Pulseaudio, ...)
    arch_chroot "pacman -S --noconfirm --needed xorg-server xorg-apps xorg-xinit xorg-twm xterm alsa-utils xorg-xbacklight pulseaudio pulseaudio-alsa xf86-input-libinput networkmanager xdg-user-dirs xdg-utils gvfs gvfs-mtp man-db neofetch acpi xf86-video-fbdev bash-completion"
    #arch_chroot "pacman -S --noconfirm --needed unace unrar zip unzip sharutils uudeview arj cabextract file-roller"
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

# Install Intel VGA
    arch_chroot "pacman -S --noconfirm --needed xf86-video-intel libva-intel-driver lib32-mesa"

# Install AMD VGA
    #arch_chroot "xf86-video-amdgpu vulkan-radeon libva-mesa-driver lib32-mesa lib32-libva-mesa-driver"

# Install desktop
    #arch_chroot "cd /home/${user_name} ; su ${user_name} -c ; yay -S --noconfirm --needed  xtitle-git sutils-git polybar dmenu2 "
    arch_chroot "pacman -S --noconfirm --needed  bspwm sxhkd xdo firefox firefox-i18n-hu alacritty picom dunst pcmanfm-gtk3 polkit-gnome ttf-dejavu"
    arch_chroot "pacman -S --noconfirm --needed  picom ttf-jetbrains-mono firefox firefox-i18n-hu alacritty dunst neovim xorg-xsetroot lxappearance-gtk3 vifm discord unclutter unrar unzip rofi xorg-xbacklight polybar"
    #arch_chroot "pacman -S --noconfirm --needed     sutils-git xtitle-git  unrar unzip urlscan w3m xcape xclip xdotool xorg-xdpyinfo youtube-dl zathura zathura-pdf-poppler zathura-ps zathura-djvu mediainfo atool fzf highlight rofi xorg-xbacklight bc task-spooler polybar docx2txt odt2txt urxvt-perls rxvt-unicode pcmanfm"    
    arch_chroot "su ${user_name} -c 'yay -S sutils-git xtitle-git dmenu2'"    
    arch_chroot "su ${user_name} -c 'mkdir -p /home/$user_name/.config/{bspwm,sxhkd}'"
    arch_chroot "su ${user_name} -c 'cp /usr/share/doc/bspwm/examples/bspwmrc /home/$user_name/.config/bspwm/'"
    arch_chroot "su ${user_name} -c 'cp /usr/share/doc/bspwm/examples/sxhkdrc /home/$user_name/.config/sxhkd/'"
    #arch_chroot "rm -rf /mnt/mnt"
    #arch_chroot "cd /home/$user_name/; rm -rf .git/ LICENSE README.md git.sh setup-git.sh "

# Set makepkg.conf
    sed -i 's/#MAKEFLAGS="-j[0-9]"/MAKEFLAGS="-j'$(nproc)'"/;s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T '$(nproc)' -z -)/;s/COMPRESSZST=(zstd -c -z -q -)/COMPRESSZST=(zstd -c -T'$(nproc)' -z -q -)/' /mnt/etc/makepkg.conf

# Boot loader

    #pacstrap /mnt grub efibootmgr
    #arch_chroot "grub-install --target=x86_64-efi --efi-directory=/boot/efi"
    #arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"

    pacstrap /mnt refind-efi efibootmgr
    arch_chroot "refind-install"
    rootuuid=$(lsblk -lno UUID /dev/sda2)
    echo "\"Archbook\" \"root=UUID=${rootuuid} rw \"" > /mnt/boot/refin_linux.conf
    echo "\"Archbook Fallback\" \"root=UUID=${rootuuid} rw initrd=/initramfs-linux-fallback.img\"" >> /mnt/boot/refin_linux.conf
    echo "\"Archbook Terminal\" \"root=UUID=${rootuuid} rw systemd.unit=multi-user.target\"" >> /mnt/boot/refin_linux.conf



# Check Laptop

    if [ -z "$(ls -A /sys/class/power_supply/)" -o "$(ls -A /sys/class/power_supply)" = "AC" ]

    then

        echo "No Laptop"

    else

        echo "Laptop"

        cp -rf install/40-libinput.conf /mnt/etc/X11/xorg.conf.d/

    fi
    

cp -rf install/75-noto-color-emoji.conf /mnt/etc/fonts/conf.avail/

# Mkinitcpio
    arch_chroot "mkinitcpio -p linux"

umount -R /mnt
