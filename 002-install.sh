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
arch_chroot "git clone https://github.com/bazeeel/baz-bspwm.git /mnt/mnt/etc/skel/"
arch_chroot "cp -rfT /mnt/mnt/etc/skel/ /etc/skel/"
