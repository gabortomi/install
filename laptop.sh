#!/bin/bash

#set -e

###############################################################################

# Author	:	Tamas Gabor

###############################################################################

# Command
arch_chroot() {
    arch-chroot /mnt /bin/bash -c "${1}"
}
artix_chroot() {
    artools-chroot /mnt "${1}"
}
user_name=tamas

# UPDATE THE SYSTEM CLOCK
timedatectl set-ntp true

# Format the partition
mkfs.fat -F32 /dev/sda1
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
reflector --verbose -l 20 -p https --sort rate --save /etc/pacman.d/mirrorlist-arch

# Install the BASE and BASE-DEVEL packages
    #pacstrap /mnt base base-devel linux linux-firmware
    basestrap /mnt base base-devel runit elogind-runit linux linux-firmware
    echo "end base"

# Fstab
    #genfstab -p /mnt >> /mnt/etc/fstab
    fstabgen -U /mnt >> /mnt/etc/fstab
        
    cp /etc/pacman.d/mirrorlist-arch /mnt/etc/pacman.d/mirrorlist-arch
    echo "" >> /mnt/etc/pacman.conf;echo "[multilib]" >> /mnt/etc/pacman.conf;echo "Include = /etc/pacman.d/mirrorlist-arch" >> /mnt/etc/pacman.conf
    echo "" >> /mnt/etc/pacman.conf;echo "[magyarch_repo]" >> /mnt/etc/pacman.conf;echo "SigLevel = Optional TrustedOnly" >> /mnt/etc/pacman.conf;echo 'Server = https://magyarchlinux.github.io/$repo/$arch' >> /mnt/etc/pacman.conf
    
    artix_chroot "pacman -Syy"

    artix_chroot "passwd root"

# Add a user
    artix_chroot "useradd -m -g users -G adm,lp,wheel,power,audio,video -s /bin/bash $user_name"
    echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers
    artix_chroot "passwd $user_name"

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
    artix_chroot "ln -s /usr/share/zoneinfo/Europe/Budapest /etc/localtime"
    artix_chroot "hwclock --systohc"
    artix_chroot "timedatectl set-ntp true"

# Hostname
    artix_chroot "echo laptop > /etc/hostname"

# Hosts
    echo "127.0.0.1	localhost" >> /mnt/etc/hosts;echo "::1		localhost" >> /mnt/etc/hosts;echo "127.0.0.1	laptop.localdomain	laptop" >> /mnt/etc/hosts

# Install basic apps (Xorg, Pulseaudio, ...)
    artix_chroot "pacman -S --noconfirm --needed networkmanager networkmanager-runit neovim"
    
    #arch_chroot "systemctl enable NetworkManager"
    artix_chroot " ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/current "

    processor=$(lspci -n | awk -F " " '{print $2 $3}' | grep ^"06" | awk -F ":" '{print $2}' | sed -n  '1p')

if [ "$processor" = "8086" ]
then
    basestrap /mnt intel-ucode
elif [ "$processor" = "1022" ]
then
    basestrap /mnt amd-ucode
fi

# Install Intel VGA
    artix_chroot "pacman -S --noconfirm --needed xf86-video-intel intel-media-driver lib32-mesa"

# Install AMD VGA
    #arch_chroot "xf86-video-amdgpu vulkan-radeon libva-mesa-driver lib32-mesa lib32-libva-mesa-driver"

# Set makepkg.conf
    sed -i 's/#MAKEFLAGS="-j[0-9]"/MAKEFLAGS="-j'$(nproc)'"/;s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T '$(nproc)' -z -)/;s/COMPRESSZST=(zstd -c -z -q -)/COMPRESSZST=(zstd -c -T'$(nproc)' -z -q -)/' /mnt/etc/makepkg.conf

# Boot loader

    basestrap /mnt grub efibootmgr
    artix_chroot "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB"
    artix_chroot "grub-mkconfig -o /boot/grub/grub.cfg"

    #pacstrap /mnt refind-efi efibootmgr
    #arch_chroot "refind-install"
    #rootuuid=$(lsblk -lno UUID /dev/sda2)
    #echo "\"Archbook\" \"root=UUID=${rootuuid} rw \"" > /mnt/boot/refind_linux.conf
    #echo "\"Archbook Fallback\" \"root=UUID=${rootuuid} rw initrd=/initramfs-linux-fallback.img\"" >> /mnt/boot/refind_linux.conf
    #echo "\"Archbook Terminal\" \"root=UUID=${rootuuid} rw systemd.unit=multi-user.target\"" >> /mnt/boot/refind_linux.conf



# Check Laptop

    if [ -z "$(ls -A /sys/class/power_supply/)" -o "$(ls -A /sys/class/power_supply)" = "AC" ]

    then

        echo "No Laptop"

    else

        echo "Laptop"

        cp -rf install/40-libinput.conf /mnt/etc/X11/xorg.conf.d/

    fi
    

#cp -rf install/75-noto-color-emoji.conf /mnt/etc/fonts/conf.avail/

#arch_chroot "curl -LO larbs.xyz/larbs.sh && sh larbs.sh"


umount -R /mnt
