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

# UPDATE THE SYSTEM CLOCK
timedatectl set-ntp true

# Format the partition
#mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
mkfs.ext4 /dev/sda3

# Mount the filesystem
mount /dev/sda2 /mnt
mkdir -p /mnt/boot
mkdir -p /mnt/home
mount /dev/sda1 /mnt/boot/
mount /dev/sda3 /mnt/home
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
    pacstrap /mnt base base-devel linux linux-firmware git nano
    echo "end base"

# Fstab
    genfstab -p /mnt >> /mnt/etc/fstab
        
    cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
    echo "" >> /mnt/etc/pacman.conf;echo "[multilib]" >> /mnt/etc/pacman.conf;echo "Include = /etc/pacman.d/mirrorlist" >> /mnt/etc/pacman.conf
    #echo "" >> /mnt/etc/pacman.conf;echo "[magyarch_repo]" >> /mnt/etc/pacman.conf;echo "SigLevel = Optional TrustedOnly" >> /mnt/etc/pacman.conf;echo 'Server = https://magyarchlinux.github.io/$repo/$arch' >> /mnt/etc/pacman.conf
    
    arch_chroot "pacman -Syy"

    arch_chroot "passwd root"

# Add a user
    #arch_chroot "useradd -m -g users -G adm,lp,wheel,power,audio,video -s /bin/bash $user_name"
    #echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers
    #arch_chroot "passwd $user_name"

# Locale
    echo "hu_HU.UTF-8 UTF-8" >> /mnt/etc/locale.gen
    echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
    arch_chroot "locale-gen"
    export LANG=hu_HU.UTF-8
    locale > /mnt/etc/locale.conf


    mkdir -p /mnt/etc/X11/xorg.conf.d/
    echo -e 'Section "InputClass"\n\tIdentifier "system-keyboard"\n\tMatchIsKeyboard "on"\n\tOption "XkbLayout" "hu"\n\tOption "XkbModel" "pc105"\n\tOption "XkbVariant" ",''"\n\tOption "XkbOptions" "grp:alt_shift_toggle"\nEndSection' > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf
    echo "KEYMAP=hu"  > /mnt/etc/vconsole.conf

# Time Zone
    arch_chroot "ln -s /usr/share/zoneinfo/Europe/Budapest /etc/localtime"
    arch_chroot "hwclock --systohc"
    arch_chroot "timedatectl set-ntp true"

# Hostname
    arch_chroot "echo laptop > /etc/hostname"

# Hosts
    echo "127.0.0.1	localhost" >> /mnt/etc/hosts;echo "::1		localhost" >> /mnt/etc/hosts;echo "127.0.0.1	laptop.localdomain	laptop" >> /mnt/etc/hosts

# Install basic apps (Xorg, Pulseaudio, ...)
    arch_chroot "pacman -S --noconfirm --needed xorg-server xorg-xinit xterm xorg-xbacklight pulseaudio pulseaudio-alsa \
    pulsemixer pamixer xf86-input-libinput  gvfs gvfs-mtp man-db acpi xf86-video-fbdev nm-connection-editor networkmanager"
    
    arch_chroot "systemctl enable NetworkManager"

    processor=$(lspci -n | awk -F " " '{print $2 $3}' | grep ^"06" | awk -F ":" '{print $2}' | sed -n  '1p')

# Yay
    #arch_chroot "cd /home/${user_name} ; su ${user_name} -c 'git clone https://aur.archlinux.org/yay-bin' ; cd yay-bin ; su ${user_name} -c 'makepkg' ; pacman -U yay-bin*x86_64* --noconfirm ; cd .. ; rm -rf yay-bin"

# Autoupdate
    arch_chroot "cd /home/${user_name} ; su ${user_name} -c 'git clone https://github.com/magyarchlinux/magyarch-scriptek.git' ; cd magyarch-scriptek/autoupdate && ./install"
    arch_chroot "rm -rf /home/tamas/magyarch-scriptek"

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

# Set makepkg.conf
    sed -i 's/#MAKEFLAGS="-j[0-9]"/MAKEFLAGS="-j'$(nproc)'"/;s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T '$(nproc)' -z -)/;s/COMPRESSZST=(zstd -c -z -q -)/COMPRESSZST=(zstd -c -T'$(nproc)' -z -q -)/' /mnt/etc/makepkg.conf

# Boot loader

    #pacstrap /mnt grub efibootmgr
    #arch_chroot "grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB"
    #arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"

    #pacstrap /mnt refind-efi efibootmgr
    #arch_chroot "refind-install"
    rootuuid=$(lsblk -lno UUID /dev/sda2)
    #echo "\"Archbook\" \"root=UUID=${rootuuid} rw \"" > /mnt/boot/refind_linux.conf
    #echo "\"Archbook Fallback\" \"root=UUID=${rootuuid} rw initrd=/initramfs-linux-fallback.img\"" >> /mnt/boot/refind_linux.conf
    #echo "\"Archbook Terminal\" \"root=UUID=${rootuuid} rw systemd.unit=multi-user.target\"" >> /mnt/boot/refind_linux.conf

    echo "${rootuuid}" >> /mnt/boot/loader/entries/arch.sh

# Check Laptop

    if [ -z "$(ls -A /sys/class/power_supply/)" -o "$(ls -A /sys/class/power_supply)" = "AC" ]

    then

        echo "No Laptop"

    else

        echo "Laptop"

        cp -rf install/40-libinput.conf /mnt/etc/X11/xorg.conf.d/

    fi
    

cp -rf install/75-noto-color-emoji.conf /mnt/etc/fonts/conf.avail/

arch_chroot "curl -LO https://raw.githubusercontent.com/gabortomi/LARBS/master/larbs.sh"


umount -R /mnt
